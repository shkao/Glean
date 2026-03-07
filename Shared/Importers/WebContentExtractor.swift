//
//  WebContentExtractor.swift
//  Glean
//
//  Created by Kasumi AI on 3/7/26.
//  Copyright 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import WebKit

@MainActor final class WebContentExtractor: NSObject {

	enum ExtractionError: LocalizedError {
		case timeout
		case navigationFailed(Error)
		case scriptFailed
		case invalidResult

		var errorDescription: String? {
			switch self {
			case .timeout:
				return "Page load timed out after 30 seconds."
			case .navigationFailed(let error):
				return "Navigation failed: \(error.localizedDescription)"
			case .scriptFailed:
				return "Content extraction script failed."
			case .invalidResult:
				return "Could not parse extracted content."
			}
		}
	}

	private static let timeoutInterval: TimeInterval = 30

	func extract(url: URL) async throws -> ExtractedArticle {
		// For preprint servers behind Cloudflare, try the API first (instant).
		if Self.isPreprintURL(url) {
			if let apiArticle = try? await extractFromPreprintAPI(url: url) {
				return apiArticle
			}
		}

		let loadURL = Self.rewriteForFullText(url)

		let config = WKWebViewConfiguration()
		config.websiteDataStore = .default()
		config.defaultWebpagePreferences.allowsContentJavaScript = true

		let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1280, height: 800), configuration: config)
		webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"

		#if os(macOS)
		let offscreenWindow = NSWindow(contentRect: CGRect(x: -10000, y: -10000, width: 1280, height: 800),
									   styleMask: [], backing: .buffered, defer: false)
		offscreenWindow.contentView = webView
		#endif

		try await loadPage(webView: webView, url: loadURL)
		await waitForContentReady(webView: webView)

		let article = try await extractContent(webView: webView, url: url)

		#if os(macOS)
		offscreenWindow.contentView = nil
		#endif

		return article
	}

	private static func isPreprintURL(_ url: URL) -> Bool {
		let host = url.host?.lowercased() ?? ""
		return host.contains("biorxiv.org") || host.contains("medrxiv.org")
	}

	/// Rewrites preprint URLs to their full-text HTML variant.
	/// e.g. biorxiv.org/content/10.1101/2024.01.01.123456v1 -> ...v1.full
	private static func rewriteForFullText(_ url: URL) -> URL {
		let host = url.host?.lowercased() ?? ""
		guard host.contains("biorxiv.org") || host.contains("medrxiv.org") else {
			return url
		}

		var path = url.path
		// Already has .full or .abstract suffix
		if path.hasSuffix(".full") || path.hasSuffix(".abstract") {
			return url
		}
		// Strip trailing slash
		if path.hasSuffix("/") {
			path = String(path.dropLast())
		}
		// Append .full to get the inline full-text HTML page
		path += ".full"

		var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
		components?.path = path
		return components?.url ?? url
	}
}

// MARK: - Private

private extension WebContentExtractor {

	/// Polls the page title to detect and wait out bot-protection challenge pages
	/// (Cloudflare "Just a moment...", etc.). Waits up to 15 seconds.
	/// Returns true if the challenge resolved, false if still on a challenge page.
	@discardableResult
	func waitForContentReady(webView: WKWebView) async -> Bool {
		let challengeTitles = ["just a moment", "attention required", "please wait", "checking your browser", "security check"]
		let maxAttempts = 15

		for _ in 0..<maxAttempts {
			let title = (try? await webView.evaluateJavaScript("document.title") as? String) ?? ""
			let lower = title.lowercased()
			let isChallenge = challengeTitles.contains { lower.contains($0) }
			if !isChallenge && !title.isEmpty {
				return true
			}
			try? await Task.sleep(for: .seconds(1))
		}
		return false
	}

	func loadPage(webView: WKWebView, url: URL) async throws {
		let request = URLRequest(url: url, timeoutInterval: Self.timeoutInterval)

		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			let handler = NavigationHandler(continuation: continuation)
			webView.navigationDelegate = handler

			// Prevent handler from being deallocated before callback fires.
			objc_setAssociatedObject(webView, "navHandler", handler, .OBJC_ASSOCIATION_RETAIN)

			webView.load(request)

			// Timeout fallback in case navigation delegate never fires.
			Task { @MainActor in
				try? await Task.sleep(for: .seconds(Self.timeoutInterval))
				handler.completeIfNeeded(with: .failure(ExtractionError.timeout))
			}
		}
	}

	func extractContent(webView: WKWebView, url: URL) async throws -> ExtractedArticle {
		let readabilityScript = """
		(function() {
			var title = document.title || '';
			var content = '';
			var excerpt = '';
			var author = '';

			// Get title from meta tags first
			var ogTitle = document.querySelector('meta[property="og:title"]');
			if (ogTitle) title = ogTitle.getAttribute('content') || title;

			// Get author
			var metaAuthor = document.querySelector('meta[name="author"]');
			if (metaAuthor) author = metaAuthor.getAttribute('content') || '';

			// Get excerpt
			var metaDesc = document.querySelector('meta[name="description"], meta[property="og:description"]');
			if (metaDesc) excerpt = metaDesc.getAttribute('content') || '';

			// Get lead image
			var leadImage = '';
			var ogImage = document.querySelector('meta[property="og:image"]');
			if (ogImage) leadImage = ogImage.getAttribute('content') || '';

			// Find the best content container (ordered by specificity)
			var contentEl = document.querySelector(
				'.post-content, .entry-content, .article-body, .article__body, ' +
				'[itemprop="articleBody"], .story-body, .c-article-body, ' +
				'.post-body, .blog-post-content, .markdown-body, ' +
				'.post, .article-content, .article__content, ' +
				'.single-post, .td-post-content, .wpb_wrapper, ' +
				'.content-area, #article-body, .rich-text'
			);
			if (!contentEl) {
				contentEl = document.querySelector('article');
			}
			if (!contentEl) {
				contentEl = document.querySelector('main, [role="main"], #content');
			}
			// Heuristic fallback: find the element with the most <p> children
			if (!contentEl || contentEl.querySelectorAll('p').length < 2) {
				var candidates = document.querySelectorAll('div, section');
				var best = contentEl;
				var bestScore = best ? best.querySelectorAll('p').length : 0;
				for (var i = 0; i < candidates.length; i++) {
					var c = candidates[i];
					var pCount = c.querySelectorAll('p').length;
					var textLen = c.innerText ? c.innerText.length : 0;
					// Must have multiple paragraphs and substantial text
					if (pCount >= 3 && textLen > 500 && pCount > bestScore) {
						// Skip very broad containers (body-level)
						if (c.querySelectorAll('nav, header, footer').length === 0 || pCount > bestScore * 2) {
							bestScore = pCount;
							best = c;
						}
					}
				}
				if (best && bestScore >= 3) contentEl = best;
			}

			if (contentEl) {
				// Clone so we can remove unwanted elements without affecting the page
				var clone = contentEl.cloneNode(true);

				// Remove navigation, headers, footers, sidebars, scripts, styles
				var removeSelectors = [
					'nav', 'header', 'footer', '.nav', '.navigation',
					'.sidebar', 'aside', '.social-share', '.share-buttons',
					'.author-info', '.author-bio', '.author-card',
					'.author-list', '.authors', '.contributor-info',
					'.author-notes', '.affiliations', '.author-affiliations',
					'script', 'style', 'iframe', 'form',
					'.ad', '.ads', '.advertisement', '[class*="promo"]',
					'.related-articles', '.recommended', '.more-stories',
					'.comments', '#comments', '.comment-section',
					'button', '.btn', '[role="button"]',
					'.download-pdf', '[data-test="download-pdf"]',

					// Academic paper: references, bibliography, citations
					'.references', '.reference-list', '.bibliography',
					'#references', '#bibliography', '#refs',
					'[data-title="References"]', '[id*="reference"]',
					'.citation-list', '.c-article-references',

					// Academic paper: methods, supplementary, extended data
					'#methods', '#supplementary', '#extended-data',
					'#supplementary-information', '#additional-information',
					'#author-information', '#acknowledgements', '#ethics',
					'#change-history', '#rights-and-permissions',
					'[data-title="Methods"]', '[data-title="Supplementary information"]',
					'[data-title="Extended data"]', '[data-title="Author information"]',
					'[data-title="Additional information"]',
					'[data-title="Rights and permissions"]',
					'[data-title="Change history"]',

					// Academic paper: article header/meta
					'.article-header', '.article__header',
					'.c-article-header', '.c-article-author-list',
					'.c-article-identifiers', '.c-article-info-details',
					'.c-article-metrics-bar',
					'.c-article-access-provider', '.c-article-main-column > header',
					'[data-test="article-identifier"]',
					'sup.c-author-list__count', 'a[data-test="author-name"]',
					'.orcid-checkmark',

					// Academic paper: figure source data, data availability
					'.c-article-section__figure-source-data',
					'[data-title="Data availability"]',
					'[data-title="Code availability"]',
					'.data-availability', '#data-availability',

					// Academic paper: figures, figure captions
					'figcaption', '.c-article-section__figure',
					'.c-article-section__figure-description',
					'[data-test="figure"]', '.figure-container',
					'.c-figure', '.c-article-figure-content',

					// Academic paper: "About this article", citation, sharing
					'.c-article-info-details', '.c-bibliographic-information',
					'.c-article-subject-list', '.c-article-about',
					'.c-crossmark', '[data-test="crossmark"]',
					'.c-article-extra-links', '.c-article-share-box',
					'.c-article-identifiers', '.c-article-rights',
					'.c-article-body__note',
					'[data-component="article-crossmark"]',

					// Related/similar content
					'.c-recommendations', '.c-reading-companion',
					'.c-article-recommendations', '.c-nature-recommended',
					'[data-test="recommended-content"]',
					'.c-article-extras', '.c-latest-content',

					// Paywall, access, purchase blocks
					'.c-article-access-provider', '.c-article-buy-box',
					'.buying-options', '.access-options', '.buy-box',
					'.paywall', '.subscription-prompt', '.access-through',
					'[data-test="access-article"]', '[data-component="buy-box"]',
					'[data-test="buy-box"]', '.c-article-body__paywall',
					'.springer-nature-buy-box', '.institution-access',
					'.c-article-access-options',

					// Generic: acknowledgements, footnotes, appendix
					'.acknowledgements', '.acknowledgments', '.footnotes',
					'.appendix', '.supplementary-material'
				];

				// Also remove sections by heading text content
				var sectionHeadings = [
					'References', 'Bibliography', 'Methods', 'Materials and Methods',
					'Supplementary Information', 'Supplementary Materials',
					'Extended Data', 'Extended data figures and tables',
					'Author Information', 'Author Contributions',
					'Additional Information', 'Acknowledgements', 'Acknowledgments',
					'Data Availability', 'Code Availability',
					'Rights and Permissions', 'Competing Interests',
					'Ethics Declarations', 'Change History',
					'Reporting Summary', 'Source Data', 'Peer Review',
					'Further Reading', 'Related Links',
					'About this article', 'Cite this article',
					'Download citation', 'Share this article',
					'Similar content being viewed by others', 'Subjects',
					'Check for updates',
					'Access through your institution', 'Buy or subscribe',
					'Access options', 'Buy this article', 'Subscribe to this journal',
					'Rent or buy this article', 'Get access', 'Log in through your institution'
				];

				// Find headings that match and remove them plus following content
				var headings = clone.querySelectorAll('h1, h2, h3, h4, h5, h6');
				headings.forEach(function(heading) {
					var text = heading.textContent.trim().replace(/\\s+/g, ' ');
					var shouldRemove = sectionHeadings.some(function(s) {
						return text.toLowerCase() === s.toLowerCase()
							|| text.toLowerCase().startsWith(s.toLowerCase());
					});
					if (shouldRemove) {
						// Remove heading and all following siblings until next heading of same or higher level
						var level = parseInt(heading.tagName.charAt(1));
						var next = heading.nextElementSibling;
						heading.remove();
						while (next) {
							var toRemove = next;
							next = next.nextElementSibling;
							if (toRemove.tagName && /^H[1-6]$/.test(toRemove.tagName)) {
								var nextLevel = parseInt(toRemove.tagName.charAt(1));
								if (nextLevel <= level) break;
							}
							toRemove.remove();
						}
					}
				});

				// Remove sections wrapped in elements with data-title or aria-label matching
				var sections = clone.querySelectorAll('section[data-title], section[aria-label], div[data-title]');
				sections.forEach(function(sec) {
					var label = (sec.getAttribute('data-title') || sec.getAttribute('aria-label') || '').trim();
					var shouldRemove = sectionHeadings.some(function(s) {
						return label.toLowerCase() === s.toLowerCase()
							|| label.toLowerCase().startsWith(s.toLowerCase());
					});
					if (shouldRemove) sec.remove();
				});

				removeSelectors.forEach(function(sel) {
					clone.querySelectorAll(sel).forEach(function(el) { el.remove(); });
				});

				// Remove figure blocks (contain long captions like "Fig. 1: ...")
				clone.querySelectorAll('figure').forEach(function(fig) { fig.remove(); });

				// Remove remaining links/paragraphs that are just "Source data" or "Full size image"
				clone.querySelectorAll('a, p, span, div').forEach(function(el) {
					var t = el.textContent.trim();
					if (t === 'Source data' || t === 'Full size image'
						|| t === 'Full size table' || t === 'Download citation'
						|| t === 'Check for updates. Verify currency and authenticity via CrossMark') {
						el.remove();
					}
				});

				// Remove duplicate h1 (renderer adds its own title)
				var h1s = clone.querySelectorAll('h1');
				h1s.forEach(function(h1) {
					if (h1.textContent.trim() === title.trim()) {
						h1.remove();
					}
				});

				// Remove empty elements (run twice to catch nested empties)
				for (var pass = 0; pass < 2; pass++) {
					clone.querySelectorAll('div, section, span, p').forEach(function(el) {
						if (el.textContent.trim() === '' && el.querySelectorAll('img, video, svg').length === 0) {
							el.remove();
						}
					});
				}

				content = clone.innerHTML.trim();
			} else {
				content = '';
			}

			return JSON.stringify({
				title: title,
				author: author,
				content: content,
				excerpt: excerpt,
				lead_image_url: leadImage,
				url: window.location.href,
				domain: window.location.hostname
			});
		})();
		"""

		let result = try await webView.evaluateJavaScript(readabilityScript)

		guard let jsonString = result as? String,
			  let jsonData = jsonString.data(using: .utf8) else {
			throw ExtractionError.scriptFailed
		}

		let decoder = JSONDecoder()
		let article = try decoder.decode(ExtractedArticle.self, from: jsonData)

		// If we got content, return it. Otherwise, try meta tag fallback.
		if let content = article.content, !content.isEmpty {
			return article
		}

		return try await extractFromMetaTags(webView: webView, url: url)
	}

	func extractFromMetaTags(webView: WKWebView, url: URL) async throws -> ExtractedArticle {
		let metaScript = """
		(function() {
			var title = '';
			var description = '';
			var image = '';

			var ogTitle = document.querySelector('meta[property="og:title"]');
			if (ogTitle) title = ogTitle.getAttribute('content') || '';
			if (!title) title = document.title || '';

			var ogDesc = document.querySelector('meta[property="og:description"]');
			if (ogDesc) description = ogDesc.getAttribute('content') || '';
			if (!description) {
				var metaDesc = document.querySelector('meta[name="description"]');
				if (metaDesc) description = metaDesc.getAttribute('content') || '';
			}

			var ogImage = document.querySelector('meta[property="og:image"]');
			if (ogImage) image = ogImage.getAttribute('content') || '';

			return JSON.stringify({
				title: title,
				content: description,
				excerpt: description,
				lead_image_url: image,
				url: window.location.href,
				domain: window.location.hostname
			});
		})();
		"""

		let result = try await webView.evaluateJavaScript(metaScript)

		guard let jsonString = result as? String,
			  let jsonData = jsonString.data(using: .utf8) else {
			throw ExtractionError.scriptFailed
		}

		let decoder = JSONDecoder()
		return try decoder.decode(ExtractedArticle.self, from: jsonData)
	}
}

// MARK: - Preprint API Fallback

private extension WebContentExtractor {

	/// Extracts article metadata from bioRxiv/medRxiv API when Cloudflare blocks the page.
	/// Returns abstract + metadata. Full text is not available via the API.
	func extractFromPreprintAPI(url: URL) async throws -> ExtractedArticle {
		let host = url.host?.lowercased() ?? ""

		guard host.contains("biorxiv.org") || host.contains("medrxiv.org") else {
			throw ExtractionError.scriptFailed
		}

		// Extract DOI from URL path like /content/10.1101/2024.01.01.123456v1
		let path = url.path
		guard let range = path.range(of: "/content/") else {
			throw ExtractionError.scriptFailed
		}
		var doi = String(path[range.upperBound...])
		doi = doi.replacingOccurrences(of: "\\.full$", with: "", options: .regularExpression)
		doi = doi.replacingOccurrences(of: "\\.abstract$", with: "", options: .regularExpression)
		doi = doi.replacingOccurrences(of: "v\\d+$", with: "", options: .regularExpression)

		let server = host.contains("medrxiv") ? "medrxiv" : "biorxiv"
		let apiURL = URL(string: "https://api.biorxiv.org/details/\(server)/\(doi)")!

		let (data, _) = try await URLSession.shared.data(from: apiURL)

		guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
			  let collection = json["collection"] as? [[String: Any]],
			  let paper = collection.first else {
			throw ExtractionError.invalidResult
		}

		let title = paper["title"] as? String
		let allAuthors = paper["authors"] as? String ?? ""
		let correspondingAuthor = paper["author_corresponding"] as? String
		let institution = paper["author_corresponding_institution"] as? String ?? ""
		let abstract = paper["abstract"] as? String ?? ""
		let category = paper["category"] as? String ?? ""
		let date = paper["date"] as? String ?? ""
		let paperType = paper["type"] as? String ?? ""
		let license = paper["license"] as? String ?? ""
		let serverName = server == "medrxiv" ? "medRxiv" : "bioRxiv"

		// Build structured HTML
		var html = ""

		// Authors
		if !allAuthors.isEmpty {
			let formatted = allAuthors
				.components(separatedBy: ";")
				.map { $0.trimmingCharacters(in: .whitespaces) }
				.filter { !$0.isEmpty }
				.joined(separator: ", ")
			html += "<p><em>\(formatted)</em></p>"
		}

		// Metadata line
		var meta: [String] = []
		if !serverName.isEmpty { meta.append(serverName) }
		if !category.isEmpty { meta.append(category.capitalized) }
		if !paperType.isEmpty { meta.append(paperType.capitalized) }
		if !date.isEmpty { meta.append("Posted \(date)") }
		if !meta.isEmpty {
			html += "<p style=\"color: #666;\">\(meta.joined(separator: " | "))</p>"
		}
		if !institution.isEmpty {
			html += "<p style=\"color: #666;\">Corresponding: \(correspondingAuthor ?? "") (\(institution))</p>"
		}

		// Abstract
		html += "<h2>Abstract</h2>"

		// Split abstract into paragraphs if it has sentence boundaries with topic shifts
		let abstractParagraphs = abstract
			.components(separatedBy: ". ")
			.reduce(into: [""]) { result, sentence in
				let current = result[result.count - 1]
				if current.count > 500 {
					result.append(sentence + ". ")
				} else {
					result[result.count - 1] = current + sentence + ". "
				}
			}
			.map { "<p>\($0.trimmingCharacters(in: .whitespaces))</p>" }
			.joined()

		html += abstractParagraphs

		if !doi.isEmpty {
			html += "<p style=\"color: #666; font-size: 0.9em;\">DOI: \(doi)</p>"
		}
		if !license.isEmpty {
			let readableLicense = license.replacingOccurrences(of: "_", with: "-").uppercased()
			html += "<p style=\"color: #999; font-size: 0.85em;\">License: \(readableLicense)</p>"
		}

		return ExtractedArticle(
			title: title,
			author: correspondingAuthor,
			datePublished: date,
			dek: nil,
			leadImageURL: nil,
			content: html,
			nextPageURL: nil,
			url: url.absoluteString,
			domain: host,
			excerpt: String(abstract.prefix(300)),
			wordCount: abstract.split(separator: " ").count,
			direction: nil,
			totalPages: nil,
			renderedPages: nil
		)
	}
}

// MARK: - NavigationHandler

/// Bridges WKNavigationDelegate callbacks into a checked continuation.
private final class NavigationHandler: NSObject, WKNavigationDelegate {

	private var continuation: CheckedContinuation<Void, Error>?

	init(continuation: CheckedContinuation<Void, Error>) {
		self.continuation = continuation
	}

	func completeIfNeeded(with result: Result<Void, Error>) {
		guard let continuation else {
			return
		}
		self.continuation = nil
		switch result {
		case .success:
			continuation.resume()
		case .failure(let error):
			continuation.resume(throwing: error)
		}
	}

	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		completeIfNeeded(with: .success(()))
	}

	func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		completeIfNeeded(with: .failure(WebContentExtractor.ExtractionError.navigationFailed(error)))
	}

	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
		completeIfNeeded(with: .failure(WebContentExtractor.ExtractionError.navigationFailed(error)))
	}
}

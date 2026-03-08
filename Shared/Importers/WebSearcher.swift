//
//  WebSearcher.swift
//  Glean
//
//  Uses a hidden WKWebView to search DuckDuckGo and find original URLs
//  for article titles extracted from screenshots.
//

import Foundation
import WebKit

@MainActor final class WebSearcher: NSObject {

	struct SearchResult {
		let url: URL
		let title: String
	}

	private static let searchTimeout: TimeInterval = 15

	/// Searches DuckDuckGo for the given query and returns top results.
	func search(query: String, maxResults: Int = 5) async -> [SearchResult] {
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty,
			  let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
			  let searchURL = URL(string: "https://duckduckgo.com/?q=\(encoded)") else {
			return []
		}

		let config = WKWebViewConfiguration()
		config.websiteDataStore = .nonPersistent()

		let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1280, height: 800), configuration: config)
		webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"

		#if os(macOS)
		let offscreenWindow = NSWindow(contentRect: CGRect(x: -10000, y: -10000, width: 1280, height: 800),
									   styleMask: [], backing: .buffered, defer: true)
		offscreenWindow.contentView = webView
		#endif

		defer {
			#if os(macOS)
			offscreenWindow.contentView = nil
			offscreenWindow.close()
			#endif
		}

		// Load the search page
		do {
			try await loadPage(webView: webView, url: searchURL)
		} catch {
			return []
		}

		// Poll for results to render (up to 5 seconds)
		let resultCheckJS = "document.querySelectorAll('a[data-testid=\"result-title-a\"], a.result__a, article a[href]').length"
		for _ in 0..<10 {
			try? await Task.sleep(for: .milliseconds(500))
			if let count = try? await webView.evaluateJavaScript(resultCheckJS) as? Int, count > 0 {
				break
			}
		}

		// Extract result links via JavaScript
		let js = """
		(function() {
			var results = [];
			// DuckDuckGo renders results in <a data-testid="result-title-a"> or <a class="result__a">
			var links = document.querySelectorAll('a[data-testid="result-title-a"], a.result__a, article a[href]');
			for (var i = 0; i < Math.min(links.length, \(maxResults)); i++) {
				var a = links[i];
				var href = a.href;
				if (href && (href.startsWith('http://') || href.startsWith('https://'))
					&& !href.includes('duckduckgo.com')) {
					results.push({
						url: href,
						title: (a.textContent || '').trim()
					});
				}
			}
			return JSON.stringify(results);
		})()
		"""

		do {
			let result = try await webView.evaluateJavaScript(js)
			guard let jsonString = result as? String,
				  let data = jsonString.data(using: .utf8),
				  let items = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
				return []
			}

			return items.compactMap { item in
				guard let urlString = item["url"],
					  let url = URL(string: urlString),
					  let title = item["title"] else {
					return nil
				}
				return SearchResult(url: url, title: title)
			}
		} catch {
			return []
		}
	}

	/// Searches for an article by title, optionally scoping to a domain.
	/// Returns the best matching URL or nil.
	func findArticleURL(title: String, domain: String? = nil) async -> URL? {
		var query = "\"\(title)\""
		if let domain {
			query = "site:\(domain) \(title)"
		}
		let results = await search(query: query, maxResults: 3)

		// If we searched with site: and got results, the first one is likely correct
		if let first = results.first {
			return first.url
		}

		// If site-scoped search failed, try without site restriction
		if domain != nil {
			let fallbackResults = await search(query: title, maxResults: 3)
			return fallbackResults.first?.url
		}

		return nil
	}

	// MARK: - Private

	private func loadPage(webView: WKWebView, url: URL) async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			let delegate = NavigationDelegate(continuation: continuation)
			webView.navigationDelegate = delegate
			objc_setAssociatedObject(webView, &NavigationDelegate.key, delegate, .OBJC_ASSOCIATION_RETAIN)

			let request = URLRequest(url: url, timeoutInterval: Self.searchTimeout)
			webView.load(request)
		}
	}
}

// MARK: - Navigation Delegate

private final class NavigationDelegate: NSObject, WKNavigationDelegate {
	static var key: UInt8 = 0
	private var continuation: CheckedContinuation<Void, Error>?

	init(continuation: CheckedContinuation<Void, Error>) {
		self.continuation = continuation
	}

	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		continuation?.resume()
		continuation = nil
	}

	func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		continuation?.resume(throwing: error)
		continuation = nil
	}

	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
		continuation?.resume(throwing: error)
		continuation = nil
	}
}

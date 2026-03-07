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
		let config = WKWebViewConfiguration()
		let webView = WKWebView(frame: .zero, configuration: config)

		try await loadPage(webView: webView, url: url)
		let article = try await extractContent(webView: webView, url: url)
		return article
	}
}

// MARK: - Private

private extension WebContentExtractor {

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
		// Try Readability-style extraction first, then fall back to meta tags.
		let readabilityScript = """
		(function() {
			var title = document.title || '';
			var content = '';
			var excerpt = '';
			var author = '';

			var article = document.querySelector('article');
			if (article) {
				content = article.innerHTML;
			} else {
				var main = document.querySelector('main, [role="main"], .post-content, .entry-content, .article-body');
				if (main) {
					content = main.innerHTML;
				} else {
					content = document.body ? document.body.innerHTML : '';
				}
			}

			var metaAuthor = document.querySelector('meta[name="author"]');
			if (metaAuthor) author = metaAuthor.getAttribute('content') || '';

			var metaDesc = document.querySelector('meta[name="description"], meta[property="og:description"]');
			if (metaDesc) excerpt = metaDesc.getAttribute('content') || '';

			var ogTitle = document.querySelector('meta[property="og:title"]');
			if (ogTitle) title = ogTitle.getAttribute('content') || title;

			var leadImage = '';
			var ogImage = document.querySelector('meta[property="og:image"]');
			if (ogImage) leadImage = ogImage.getAttribute('content') || '';

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

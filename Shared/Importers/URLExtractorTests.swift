// URLExtractorTests.swift
// These tests verify URLExtractor's URL detection logic.
// Run via the Xcode test plan since URLExtractor lives in the app target.

#if DEBUG
import Foundation
import Testing

@Suite("URLExtractor")
struct URLExtractorTests {

	@Test("Extracts HTTP URLs from plain text")
	func extractsHTTPURLs() {
		let text = "Check out https://example.com and http://test.org/page"
		let urls = URLExtractor.extractURLs(from: text)
		#expect(urls.count == 2)
		#expect(urls[0].absoluteString == "https://example.com")
		#expect(urls[1].absoluteString == "http://test.org/page")
	}

	@Test("Deduplicates identical URLs")
	func deduplicates() {
		let text = "Visit https://example.com and then https://example.com again"
		let urls = URLExtractor.extractURLs(from: text)
		#expect(urls.count == 1)
	}

	@Test("Filters out non-HTTP schemes")
	func filtersNonHTTP() {
		let text = "ftp://files.example.com and mailto:user@example.com and https://valid.com"
		let urls = URLExtractor.extractURLs(from: text)
		#expect(urls.count == 1)
		#expect(urls[0].host == "valid.com")
	}

	@Test("Returns empty for text with no URLs")
	func noURLs() {
		let text = "Just some regular text without any links"
		let urls = URLExtractor.extractURLs(from: text)
		#expect(urls.isEmpty)
	}

	@Test("Returns empty for empty string")
	func emptyString() {
		let urls = URLExtractor.extractURLs(from: "")
		#expect(urls.isEmpty)
	}

	@Test("Handles URLs mixed with newlines")
	func urlsWithNewlines() {
		let text = """
		https://first.com
		https://second.com
		https://third.com
		"""
		let urls = URLExtractor.extractURLs(from: text)
		#expect(urls.count == 3)
	}

	@Test("Handles URLs with query parameters and fragments")
	func urlsWithQueryAndFragment() {
		let text = "See https://example.com/page?id=123&ref=test#section"
		let urls = URLExtractor.extractURLs(from: text)
		#expect(urls.count == 1)
		#expect(urls[0].absoluteString.contains("id=123"))
	}
}
#endif

//
//  ScreenshotImporter.swift
//  Glean
//
//  Vision-based OCR for screenshots. Extracts URLs directly and analyzes
//  text to detect web content (titles, domains) for URL lookup.
//

import Foundation
import Vision
import CoreGraphics

@MainActor final class ScreenshotImporter {

	struct ImportResult {
		let urls: [URL]
		let errors: [Error]
	}

	struct ScreenshotAnalysis {
		let ocrText: String
		let directURLs: [URL]
		let detectedTitle: String?
		let detectedDomain: String?
		let isLikelyWebContent: Bool
	}

	func importScreenshots(_ images: [CGImage]) async -> ImportResult {
		var allURLs = [URL]()
		var allErrors = [Error]()
		var seen = Set<String>()

		for image in images {
			do {
				let text = try await recognizeText(in: image)
				let urls = URLExtractor.extractURLs(from: text)
				for url in urls {
					if seen.insert(url.absoluteString).inserted {
						allURLs.append(url)
					}
				}
			} catch {
				allErrors.append(error)
			}
		}

		return ImportResult(urls: allURLs, errors: allErrors)
	}

	/// Analyzes a screenshot for web content: extracts URLs, title, domain.
	func analyzeScreenshot(_ image: CGImage) async throws -> ScreenshotAnalysis {
		let text = try await recognizeText(in: image)
		let urls = URLExtractor.extractURLs(from: text)
		let lines = text.components(separatedBy: "\n")
			.map { $0.trimmingCharacters(in: .whitespaces) }
			.filter { !$0.isEmpty }

		let domain = Self.detectDomain(from: lines)
		let title = Self.extractTitle(from: lines)
		let isWebContent = !urls.isEmpty || domain != nil || Self.hasWebContentSignals(lines)

		return ScreenshotAnalysis(
			ocrText: text,
			directURLs: urls,
			detectedTitle: title,
			detectedDomain: domain,
			isLikelyWebContent: isWebContent
		)
	}
}

// MARK: - OCR

private extension ScreenshotImporter {

	func recognizeText(in image: CGImage) async throws -> String {
		try await withCheckedThrowingContinuation { continuation in
			let request = VNRecognizeTextRequest { request, error in
				if let error {
					continuation.resume(throwing: error)
					return
				}

				guard let observations = request.results as? [VNRecognizedTextObservation] else {
					continuation.resume(returning: "")
					return
				}

				let text = observations.compactMap { observation in
					observation.topCandidates(1).first?.string
				}.joined(separator: "\n")

				continuation.resume(returning: text)
			}

			request.recognitionLevel = .accurate
			request.usesLanguageCorrection = true

			let handler = VNImageRequestHandler(cgImage: image, options: [:])
			do {
				try handler.perform([request])
			} catch {
				continuation.resume(throwing: error)
			}
		}
	}
}

// MARK: - Text Analysis

extension ScreenshotImporter {

	private static let domainRegexes: [NSRegularExpression] = {
		let patterns = [
			#"[a-zA-Z0-9][-a-zA-Z0-9]*\.[a-zA-Z0-9][-a-zA-Z0-9]*\.(com|org|net|edu|gov|io|dev|app|co|me|info|ac|uk|jp|tw|cn|kr|de|fr|es)"#,
			#"[a-zA-Z0-9][-a-zA-Z0-9]+\.(com|org|net|edu|gov|io|dev|app)"#
		]
		return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
	}()

	/// Looks for domain names in the top portion of OCR text (address bar area).
	static func detectDomain(from lines: [String]) -> String? {
		let topLines = lines.prefix(8)
		for regex in domainRegexes {
			for line in topLines {
				let range = NSRange(line.startIndex..., in: line)
				if let match = regex.firstMatch(in: line, range: range),
				   let matchRange = Range(match.range, in: line) {
					return String(line[matchRange]).lowercased()
				}
			}
		}
		return nil
	}

	/// Extracts the most likely article title from OCR lines.
	/// Prefers the longest substantial line that isn't UI chrome or a URL.
	static func extractTitle(from lines: [String]) -> String? {
		let uiPatterns: Set<String> = [
			"share", "bookmark", "back", "forward", "search", "menu",
			"settings", "open pdf", "cite", "jump to", "supporting information",
			"open in app", "sign in", "log in", "subscribe", "download",
			"more", "cancel", "done", "close"
		]

		let candidates = lines.filter { line in
			let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
			guard trimmed.count >= 15 else { return false }
			guard !trimmed.contains("http://") && !trimmed.contains("https://") else { return false }
			guard !trimmed.contains(".com/") && !trimmed.contains(".org/") else { return false }

			let lower = trimmed.lowercased()
			// Skip if it's a known UI element
			if uiPatterns.contains(lower) { return false }
			// Skip lines that are mostly numbers (timestamps, counts)
			let digitCount = trimmed.filter(\.isNumber).count
			if Double(digitCount) / Double(trimmed.count) > 0.5 { return false }

			return true
		}

		// Return the longest candidate, which is typically the article title
		return candidates.max(by: { $0.count < $1.count })
	}

	/// Checks for signals that the screenshot is from a web page.
	static func hasWebContentSignals(_ lines: [String]) -> Bool {
		let signals = [
			"article", "open access", "doi:", "cite", "published",
			"abstract", "read more", "subscribe", "newsletter",
			"comments", "related articles", "references",
			"journal", "volume", "issue", "pages"
		]
		let text = lines.joined(separator: " ").lowercased()
		let matchCount = signals.filter { text.contains($0) }.count
		return matchCount >= 2
	}
}

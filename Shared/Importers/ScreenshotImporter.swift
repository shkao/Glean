//
//  ScreenshotImporter.swift
//  Glean
//
//  Created by Kasumi AI on 3/7/26.
//  Copyright 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Vision
import CoreGraphics

@MainActor final class ScreenshotImporter {

	struct ImportResult {
		let urls: [URL]
		let errors: [Error]
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
}

// MARK: - Private

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

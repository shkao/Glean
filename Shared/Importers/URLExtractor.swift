//
//  URLExtractor.swift
//  Glean
//
//  Created by Kasumi AI on 3/7/26.
//  Copyright 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct URLExtractor {

	static func extractURLs(from text: String) -> [URL] {
		guard !text.isEmpty else {
			return []
		}

		let detector: NSDataDetector
		do {
			detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
		} catch {
			return []
		}

		let range = NSRange(text.startIndex..., in: text)
		let matches = detector.matches(in: text, options: [], range: range)

		var seen = Set<String>()
		var urls = [URL]()

		for match in matches {
			guard let url = match.url else {
				continue
			}
			guard let scheme = url.scheme?.lowercased(),
				  scheme == "http" || scheme == "https" else {
				continue
			}
			let canonical = url.absoluteString
			if seen.insert(canonical).inserted {
				urls.append(url)
			}
		}

		return urls
	}
}

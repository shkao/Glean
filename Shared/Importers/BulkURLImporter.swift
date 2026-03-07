//
//  BulkURLImporter.swift
//  Glean
//
//  Created by Kasumi AI on 3/7/26.
//  Copyright 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Account

@MainActor final class BulkURLImporter {

	struct BulkImportResult {
		let imported: Int
		let failed: Int
		let errors: [Error]
	}

	private let extractor = WebContentExtractor()

	func importURLs(from text: String, to account: Account, folder: Folder?) async -> BulkImportResult {
		let urls = URLExtractor.extractURLs(from: text)
		let container: Container = folder ?? account

		var imported = 0
		var errors = [Error]()

		for url in urls {
			do {
				let article = try await extractor.extract(url: url)
				let feedName = article.title ?? url.host ?? url.absoluteString

				let feed: Feed = try await withCheckedThrowingContinuation { continuation in
					account.createFeed(url: url.absoluteString, name: feedName, container: container, validateFeed: false) { result in
						continuation.resume(with: result)
					}
				}

				// Store extracted content as the feed's content hash for later rendering.
				if let content = article.content {
					feed.contentHash = content
				}

				imported += 1
			} catch {
				errors.append(error)
			}
		}

		return BulkImportResult(imported: imported, failed: errors.count, errors: errors)
	}
}

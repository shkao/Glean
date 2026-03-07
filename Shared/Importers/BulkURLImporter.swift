//
//  BulkURLImporter.swift
//  Glean
//
//  Created by Kasumi AI on 3/7/26.
//  Copyright 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Account
import RSParser

@MainActor final class BulkURLImporter {

	struct BulkImportResult {
		let imported: Int
		let failed: Int
		let errors: [Error]
	}

	private let extractor = WebContentExtractor()

	func importURLs(from text: String, to account: Account, folder: Folder?, progress: ((Int, Int) -> Void)? = nil) async -> BulkImportResult {
		let urls = URLExtractor.extractURLs(from: text)
		return await importURLs(urls, to: account, folder: folder, progress: progress)
	}

	func importURLs(_ urls: [URL], to account: Account, folder: Folder?, progress: ((Int, Int) -> Void)? = nil) async -> BulkImportResult {
		let container: Container = folder ?? account

		var imported = 0
		var errors = [Error]()
		let total = urls.count

		for url in urls {
			do {
				let extracted = try await extractor.extract(url: url)
				let feedName = extracted.title ?? url.host ?? url.absoluteString

				let feed: Feed = try await withCheckedThrowingContinuation { continuation in
					account.createFeed(url: url.absoluteString, name: feedName, container: container, validateFeed: false) { result in
						continuation.resume(with: result)
					}
				}

				let parsedItem = ParsedItem(
					syncServiceID: nil,
					uniqueID: url.absoluteString,
					feedURL: url.absoluteString,
					url: url.absoluteString,
					externalURL: nil,
					title: extracted.title,
					language: nil,
					contentHTML: extracted.content,
					contentText: nil,
					markdown: nil,
					summary: extracted.excerpt,
					imageURL: extracted.leadImageURL,
					bannerImageURL: nil,
					datePublished: Date(),
					dateModified: nil,
					authors: nil,
					tags: nil,
					attachments: nil
				)

				_ = try await account.updateAsync(feedID: feed.feedID, parsedItems: Set([parsedItem]), deleteOlder: false)

				imported += 1
			} catch {
				errors.append(error)
			}

			progress?(imported + errors.count, total)
		}

		return BulkImportResult(imported: imported, failed: errors.count, errors: errors)
	}
}

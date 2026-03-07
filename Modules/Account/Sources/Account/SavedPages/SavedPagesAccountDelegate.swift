//
//  SavedPagesAccountDelegate.swift
//  Glean
//
//  Created by Kasumi AI on 3/7/26.
//  Copyright 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import Articles
import RSWeb
import Secrets

@MainActor final class SavedPagesAccountDelegate: AccountDelegate {

	weak var account: Account?

	let behaviors: AccountBehaviors = [.disallowOPMLImports, .disallowFolderManagement]
	let isOPMLImportInProgress = false

	var progressInfo = ProgressInfo() {
		didSet {
			if progressInfo != oldValue {
				postProgressInfoDidChangeNotification()
			}
		}
	}

	let server: String? = nil
	var credentials: Credentials?
	var accountSettings: AccountSettings?

	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable: Any]) async {
	}

	@MainActor func refreshAll(for account: Account) async throws {
	}

	@MainActor func syncArticleStatus(for account: Account) async throws {
	}

	@MainActor func sendArticleStatus(for account: Account) async throws {
	}

	@MainActor func refreshArticleStatus(for account: Account) async throws {
	}

	@MainActor func importOPML(for account: Account, opmlFile: URL) async throws {
		throw AccountError.invalidParameter
	}

	@MainActor func createFeed(for account: Account, url urlString: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {
		guard let url = URL(string: urlString) else {
			throw AccountError.invalidParameter
		}

		guard !account.hasFeed(withURL: urlString) else {
			throw AccountError.createErrorAlreadySubscribed
		}

		let feed = account.createFeed(with: name, url: url.absoluteString, feedID: url.absoluteString, homePageURL: url.absoluteString)
		feed.editedName = name
		container.addFeedToTreeAtTopLevel(feed)

		return feed
	}

	@MainActor func renameFeed(for account: Account, with feed: Feed, to name: String) async throws {
		feed.editedName = name
	}

	@MainActor func removeFeed(account: Account, feed: Feed, container: Container) async throws {
		container.removeFeedFromTreeAtTopLevel(feed)
	}

	@MainActor func moveFeed(account: Account, feed: Feed, sourceContainer: Container, destinationContainer: Container) async throws {
		sourceContainer.removeFeedFromTreeAtTopLevel(feed)
		destinationContainer.addFeedToTreeAtTopLevel(feed)
	}

	@MainActor func addFeed(account: Account, feed: Feed, container: Container) async throws {
		container.addFeedToTreeAtTopLevel(feed)
	}

	@MainActor func restoreFeed(for account: Account, feed: Feed, container: Container) async throws {
		container.addFeedToTreeAtTopLevel(feed)
	}

	@MainActor func createFolder(for account: Account, name: String) async throws -> Folder {
		guard let folder = account.ensureFolder(with: name) else {
			throw AccountError.invalidParameter
		}
		return folder
	}

	@MainActor func renameFolder(for account: Account, with folder: Folder, to name: String) async throws {
		folder.name = name
	}

	@MainActor func removeFolder(for account: Account, with folder: Folder) async throws {
		account.removeFolderFromTree(folder)
	}

	@MainActor func restoreFolder(for account: Account, folder: Folder) async throws {
		account.addFolderToTree(folder)
	}

	@MainActor func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) async throws {
		try await account.updateAsync(articles: articles, statusKey: statusKey, flag: flag)
	}

	func accountDidInitialize(_ account: Account) {
		self.account = account
	}

	func accountWillBeDeleted(_ account: Account) {
	}

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?) async throws -> Credentials? {
		nil
	}

	@MainActor func suspendNetwork() {
	}

	@MainActor func suspendDatabase() {
	}

	@MainActor func resume() {
	}
}

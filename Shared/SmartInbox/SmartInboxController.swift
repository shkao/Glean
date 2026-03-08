//
//  SmartInboxController.swift
//  Glean
//
//  Orchestrates LLM-based feed classification and folder organization.
//

import Foundation
import os
import Account
import Articles
import OllamaService

@MainActor final class SmartInboxController {

  private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.shkao.Glean", category: "SmartInboxController")

  struct ProposedMove {
    let feed: Feed
    let sourceContainer: Container
    var destinationFolderName: String
    var isAccepted: Bool = true
  }

  struct ProposedRename {
    let feed: Feed
    let suggestedName: String
    var isAccepted: Bool = true
  }

  struct Proposal {
    let account: Account
    var moves: [ProposedMove]
    var renames: [ProposedRename]
    var categoryNames: [String]
  }

  enum SmartInboxError: Error {
    case noAPIKey
    case noFeedsToClassify
  }

  func generateProposal(
    for account: Account,
    includeAlreadyCategorized: Bool
  ) async throws -> Proposal {
    let settings = OpenRouterSettings.load()
    guard settings.isConfigured else {
      throw SmartInboxError.noAPIKey
    }

    let feedsToClassify: [(feed: Feed, container: Container)]
    if includeAlreadyCategorized {
      feedsToClassify = gatherAllFeeds(in: account)
    } else {
      feedsToClassify = gatherUncategorizedFeeds(in: account)
    }

    guard !feedsToClassify.isEmpty else {
      throw SmartInboxError.noFeedsToClassify
    }

    var feedInfos: [FeedClassifier.FeedInfo] = []
    for (feed, _) in feedsToClassify {
      let titles = recentArticleTitles(for: feed, in: account)
      feedInfos.append(FeedClassifier.FeedInfo(
        id: feed.feedID,
        name: feed.nameForDisplay,
        url: feed.url,
        recentTitles: titles
      ))
    }

    Self.logger.info("Classifying \(feedInfos.count) feeds via OpenRouter")
    let client = OpenRouterClient(apiKey: settings.apiKey, model: settings.model)
    let classifier = FeedClassifier(client: client)
    let result = try await classifier.classify(feeds: feedInfos)

    let feedLookup = Dictionary(uniqueKeysWithValues: feedsToClassify.map { ($0.feed.feedID, $0) })
    var moves: [ProposedMove] = []
    var categoryNames: [String] = []

    for (folderName, feedIDs) in result.categories.sorted(by: { $0.key < $1.key }) {
      categoryNames.append(folderName)
      for feedID in feedIDs {
        guard let entry = feedLookup[feedID] else { continue }
        moves.append(ProposedMove(
          feed: entry.feed,
          sourceContainer: entry.container,
          destinationFolderName: folderName
        ))
      }
    }

    var renames: [ProposedRename] = []
    for (feedID, suggestedName) in result.renames {
      guard let entry = feedLookup[feedID] else { continue }
      if entry.feed.nameForDisplay != suggestedName {
        renames.append(ProposedRename(
          feed: entry.feed,
          suggestedName: suggestedName
        ))
      }
    }

    return Proposal(
      account: account,
      moves: moves,
      renames: renames,
      categoryNames: categoryNames
    )
  }

  func execute(proposal: Proposal) async throws {
    let account = proposal.account

    for move in proposal.moves where move.isAccepted {
      guard let folder = account.ensureFolder(withFolderNames: [move.destinationFolderName]) else {
        continue
      }

      if let sourceFolder = move.sourceContainer as? Folder,
         sourceFolder.name == move.destinationFolderName {
        continue
      }

      await withCheckedContinuation { continuation in
        account.moveFeed(move.feed, from: move.sourceContainer, to: folder) { _ in
          continuation.resume()
        }
      }
    }

    for rename in proposal.renames where rename.isAccepted {
      try await account.renameFeed(rename.feed, name: rename.suggestedName)
    }
  }

  // MARK: - Helpers

  private func gatherUncategorizedFeeds(in account: Account) -> [(feed: Feed, container: Container)] {
    account.topLevelFeeds.map { (feed: $0, container: account as Container) }
  }

  private func gatherAllFeeds(in account: Account) -> [(feed: Feed, container: Container)] {
    var result: [(feed: Feed, container: Container)] = []
    for feed in account.topLevelFeeds {
      result.append((feed: feed, container: account as Container))
    }
    if let folders = account.folders {
      for folder in folders {
        for feed in folder.topLevelFeeds {
          result.append((feed: feed, container: folder as Container))
        }
      }
    }
    return result
  }

  private func recentArticleTitles(for feed: Feed, in account: Account) -> [String] {
    guard let articles = try? account.fetchArticles(.feed(feed)) else {
      return []
    }
    return articles
      .sorted { ($0.datePublished ?? .distantPast) > ($1.datePublished ?? .distantPast) }
      .prefix(5)
      .compactMap(\.title)
  }
}

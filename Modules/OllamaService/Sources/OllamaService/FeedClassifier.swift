import Foundation

public struct FeedClassifier: Sendable {

  public struct FeedInfo: Sendable {
    public let id: String
    public let name: String
    public let url: String
    public let recentTitles: [String]

    public init(id: String, name: String, url: String, recentTitles: [String]) {
      self.id = id
      self.name = name
      self.url = url
      self.recentTitles = recentTitles
    }
  }

  public struct ClassificationResult: Sendable {
    public let categories: [String: [String]]
    public let renames: [String: String]  // feedID -> suggested clean name
  }

  private let client: OpenRouterClient

  private static let systemPrompt = """
    You are a feed organizer. Given a list of RSS feeds, do two things:

    1. Classify them into 3-8 topical folders.
    2. Suggest shorter, cleaner display names for feeds with noisy names.

    Folder name rules:
    - 1-2 words max. Use simple nouns: "AI", "Biology", "News", "Dev Tools".
    - No ampersands. No "& More". No generic words like "Miscellaneous".

    Rename rules:
    - Strip platform suffixes: " - Medium", " on Medium", " | Substack".
    - Strip noise: "RSS Feed", "The latest research from", colons, pipes, dashes used as separators.
    - Keep the core identity. "Neo4j Developer Blog - Medium" -> "Neo4j Blog".
    - "Target identification : nature.com subject feeds" -> "Nature Target ID".
    - "Stories by Tomaz Bratanic on Medium" -> "Tomaz Bratanic".
    - "The latest research from Google" -> "Google Research".
    - Make every name as short as possible while staying recognizable.
    - Only include feeds that actually need renaming.

    Return ONLY valid JSON, no markdown, no code fences:
    {"categories": {"Folder": ["feedID1"]}, "renames": {"feedID1": "Short Name"}}

    Every feed ID must appear in exactly one folder.
    """

  public init(client: OpenRouterClient) {
    self.client = client
  }

  /// Classifies feeds into topical categories and suggests name cleanups.
  public func classify(feeds: [FeedInfo]) async throws -> ClassificationResult {
    guard !feeds.isEmpty else {
      return ClassificationResult(categories: [:], renames: [:])
    }

    let userPrompt = buildUserPrompt(feeds: feeds)
    let response = try await client.chatCompletion(
      system: Self.systemPrompt,
      user: userPrompt
    )

    return try parseResponse(response, knownIDs: Set(feeds.map(\.id)))
  }

  private func buildUserPrompt(feeds: [FeedInfo]) -> String {
    var lines: [String] = ["Classify these feeds and suggest cleaner names where needed:\n"]
    for feed in feeds {
      let domain = URL(string: feed.url)?.host ?? feed.url
      var line = "- ID: \(feed.id) | Name: \(feed.name) | Domain: \(domain)"
      if !feed.recentTitles.isEmpty {
        let titles = feed.recentTitles.prefix(5).joined(separator: "; ")
        line += " | Articles: \(titles)"
      }
      lines.append(line)
    }
    return lines.joined(separator: "\n")
  }

  private func parseResponse(_ response: String, knownIDs: Set<String>) throws -> ClassificationResult {
    let cleaned = response
      .replacingOccurrences(of: "```json", with: "")
      .replacingOccurrences(of: "```", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard let data = cleaned.data(using: .utf8) else {
      throw OpenRouterError.invalidJSON
    }

    struct RawResult: Codable {
      let categories: [String: [String]]
      let renames: [String: String]?
    }

    let raw = try JSONDecoder().decode(RawResult.self, from: data)

    // Filter hallucinated IDs and deduplicate (first category wins)
    var seen = Set<String>()
    var filtered: [String: [String]] = [:]
    for (folder, ids) in raw.categories.sorted(by: { $0.key < $1.key }) {
      let validIDs = ids.filter { knownIDs.contains($0) && !seen.contains($0) }
      seen.formUnion(validIDs)
      if !validIDs.isEmpty {
        filtered[folder] = validIDs
      }
    }

    // Filter renames to known IDs only
    var validRenames: [String: String] = [:]
    if let renames = raw.renames {
      for (id, name) in renames where knownIDs.contains(id) {
        validRenames[id] = name
      }
    }

    return ClassificationResult(categories: filtered, renames: validRenames)
  }
}

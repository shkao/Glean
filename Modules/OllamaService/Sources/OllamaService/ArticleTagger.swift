import Foundation

public struct ArticleTagger: Sendable {
  private let client: OllamaClient
  private let model: String

  private static let systemPrompt = """
    Return exactly 3-5 comma-separated topic tags for the following article. \
    Return only the tags, nothing else.
    """

  public init(client: OllamaClient, model: String) {
    self.client = client
    self.model = model
  }

  /// Generates topic tags for the article. Returns 3-5 trimmed tag strings.
  public func generateTags(articleText: String) async throws -> [String] {
    let response = try await client.generateFull(
      model: model,
      prompt: articleText,
      system: Self.systemPrompt
    )
    return response
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }
}

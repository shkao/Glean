import Foundation

public struct ArticleSummarizer: Sendable {
  private let client: OllamaClient
  private let model: String

  private static let maxInputLength = 4000

  private static let systemPrompt = """
    You are a concise article summarizer. Summarize the following article \
    in 2-3 sentences. Focus on the key points and main argument.
    """

  public init(client: OllamaClient, model: String) {
    self.client = client
    self.model = model
  }

  /// Streams a summary of the provided article text.
  public func summarize(articleText: String) async throws -> AsyncThrowingStream<String, Error> {
    let truncated = String(articleText.prefix(Self.maxInputLength))
    return try await client.generate(
      model: model,
      prompt: truncated,
      system: Self.systemPrompt
    )
  }
}

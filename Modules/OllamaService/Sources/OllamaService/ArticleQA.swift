import Foundation

public struct ArticleQA: Sendable {
  private let client: OllamaClient
  private let model: String

  public init(client: OllamaClient, model: String) {
    self.client = client
    self.model = model
  }

  /// Streams an answer to the question using the article as context.
  public func ask(
    question: String,
    articleText: String
  ) async throws -> AsyncThrowingStream<String, Error> {
    let systemPrompt = """
      You are a helpful assistant. Answer the user's question based only on \
      the following article context. If the answer is not in the article, say so.

      Article:
      \(articleText)
      """
    return try await client.generate(
      model: model,
      prompt: question,
      system: systemPrompt
    )
  }
}

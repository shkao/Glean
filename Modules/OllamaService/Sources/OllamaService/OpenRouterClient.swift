import Foundation
import os

public final class OpenRouterClient: Sendable {
  private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.shkao.Glean", category: "OpenRouterClient")

  private let apiKey: String
  private let model: String
  private let session: URLSession
  private let baseURL: String

  public init(
    apiKey: String,
    model: String = OpenRouterSettings.defaultModel,
    baseURL: String = "https://openrouter.ai/api/v1"
  ) {
    self.apiKey = apiKey
    self.model = model
    self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
    self.session = URLSession.shared
  }

  /// Sends a chat completion request and returns the assistant's reply.
  public func chatCompletion(system: String, user: String) async throws -> String {
    guard let url = URL(string: "\(baseURL)/chat/completions") else {
      throw OpenRouterError.invalidURL
    }

    let body = ChatCompletionRequest(
      model: model,
      messages: [
        .init(role: "system", content: system),
        .init(role: "user", content: user)
      ]
    )

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONEncoder().encode(body)

    Self.logger.debug("POST \(url.absoluteString) model=\(self.model)")

    let (data, response) = try await session.data(for: request)
    try validateResponse(response, data: data)

    let result = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
    guard let content = result.choices.first?.message.content else {
      throw OpenRouterError.emptyResponse
    }
    return content
  }

  /// Returns true if the API key is valid and the service is reachable.
  public func checkAvailability() async -> Bool {
    guard let url = URL(string: "\(baseURL)/models") else {
      return false
    }
    var request = URLRequest(url: url)
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    do {
      let (_, response) = try await session.data(for: request)
      if let httpResponse = response as? HTTPURLResponse {
        return httpResponse.statusCode == 200
      }
      return false
    } catch {
      return false
    }
  }

  private func validateResponse(_ response: URLResponse, data: Data) throws {
    guard let httpResponse = response as? HTTPURLResponse else {
      throw OpenRouterError.invalidResponse
    }
    guard (200...299).contains(httpResponse.statusCode) else {
      let body = String(data: data, encoding: .utf8) ?? "(unreadable)"
      Self.logger.error("HTTP \(httpResponse.statusCode): \(body)")
      throw OpenRouterError.httpError(statusCode: httpResponse.statusCode)
    }
  }
}

// MARK: - Errors

public enum OpenRouterError: Error, Sendable {
  case invalidURL
  case invalidResponse
  case httpError(statusCode: Int)
  case emptyResponse
  case invalidJSON
}

// MARK: - Request/Response Models

struct ChatCompletionRequest: Codable, Sendable {
  let model: String
  let messages: [Message]

  struct Message: Codable, Sendable {
    let role: String
    let content: String
  }
}

struct ChatCompletionResponse: Codable, Sendable {
  let choices: [Choice]

  struct Choice: Codable, Sendable {
    let message: ResponseMessage
  }

  struct ResponseMessage: Codable, Sendable {
    let content: String?
  }
}

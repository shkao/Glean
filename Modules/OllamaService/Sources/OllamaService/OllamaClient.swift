import Foundation

public final class OllamaClient: Sendable {
  private let baseURL: URL
  private let session: URLSession

  public init(baseURL: String = "http://localhost:11434") {
    self.baseURL = URL(string: baseURL) ?? URL(string: "http://localhost:11434")!
    self.session = URLSession.shared
  }

  // MARK: - Availability

  /// Returns true if the Ollama server is reachable.
  public func checkAvailability() async -> Bool {
    guard let url = URL(string: "/api/tags", relativeTo: baseURL) else {
      return false
    }
    do {
      let (_, response) = try await session.data(from: url)
      if let httpResponse = response as? HTTPURLResponse {
        return httpResponse.statusCode == 200
      }
      return false
    } catch {
      return false
    }
  }

  // MARK: - Models

  /// Fetches the list of locally available models.
  public func listModels() async throws -> [OllamaModel] {
    guard let url = URL(string: "/api/tags", relativeTo: baseURL) else {
      throw OllamaError.invalidURL
    }
    let (data, response) = try await session.data(from: url)
    try validateResponse(response)
    let tagsResponse = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
    return tagsResponse.models
  }

  // MARK: - Generate (streaming)

  /// Streams generated tokens from the model as NDJSON.
  public func generate(
    model: String,
    prompt: String,
    system: String? = nil
  ) async throws -> AsyncThrowingStream<String, Error> {
    guard let url = URL(string: "/api/generate", relativeTo: baseURL) else {
      throw OllamaError.invalidURL
    }

    let requestBody = OllamaGenerateRequest(
      model: model,
      prompt: prompt,
      system: system,
      stream: true
    )

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(requestBody)

    let (bytes, response) = try await session.bytes(for: request)
    try validateResponse(response)

    return AsyncThrowingStream { continuation in
      let task = Task {
        do {
          for try await line in bytes.lines {
            if Task.isCancelled { break }
            guard !line.isEmpty else { continue }
            guard let lineData = line.data(using: .utf8) else { continue }
            let chunk = try JSONDecoder().decode(OllamaGenerateResponse.self, from: lineData)
            if !chunk.response.isEmpty {
              continuation.yield(chunk.response)
            }
            if chunk.done {
              break
            }
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }

  // MARK: - Generate (non-streaming)

  /// Runs a single completion and returns the full response.
  public func generateFull(
    model: String,
    prompt: String,
    system: String? = nil
  ) async throws -> String {
    guard let url = URL(string: "/api/generate", relativeTo: baseURL) else {
      throw OllamaError.invalidURL
    }

    let requestBody = OllamaGenerateRequest(
      model: model,
      prompt: prompt,
      system: system,
      stream: false
    )

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(requestBody)

    let (data, response) = try await session.data(for: request)
    try validateResponse(response)
    let result = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)
    return result.response
  }

  // MARK: - Helpers

  private func validateResponse(_ response: URLResponse) throws {
    guard let httpResponse = response as? HTTPURLResponse else {
      throw OllamaError.invalidResponse
    }
    guard (200...299).contains(httpResponse.statusCode) else {
      throw OllamaError.httpError(statusCode: httpResponse.statusCode)
    }
  }
}

// MARK: - Errors

public enum OllamaError: Error, Sendable {
  case invalidURL
  case invalidResponse
  case httpError(statusCode: Int)
}

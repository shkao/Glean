import Foundation

public struct OllamaModel: Codable, Sendable {
  public let name: String
  public let modifiedAt: String
  public let size: Int64

  enum CodingKeys: String, CodingKey {
    case name
    case modifiedAt = "modified_at"
    case size
  }
}

public struct OllamaTagsResponse: Codable, Sendable {
  public let models: [OllamaModel]
}

public struct OllamaGenerateRequest: Codable, Sendable {
  public let model: String
  public let prompt: String
  public let system: String?
  public let stream: Bool

  public init(model: String, prompt: String, system: String? = nil, stream: Bool = true) {
    self.model = model
    self.prompt = prompt
    self.system = system
    self.stream = stream
  }
}

public struct OllamaGenerateResponse: Codable, Sendable {
  public let model: String
  public let response: String
  public let done: Bool
}

import Foundation

public struct OllamaModelDetails: Codable, Sendable {
  public let family: String?
  public let parameterSize: String?
  public let quantizationLevel: String?

  enum CodingKeys: String, CodingKey {
    case family
    case parameterSize = "parameter_size"
    case quantizationLevel = "quantization_level"
  }
}

public struct OllamaModel: Codable, Sendable {
  public let name: String
  public let size: Int64
  public let modifiedAt: String
  public let details: OllamaModelDetails?

  enum CodingKeys: String, CodingKey {
    case name
    case size
    case modifiedAt = "modified_at"
    case details
  }

  /// Model size on disk in GB, rounded to 1 decimal.
  public var sizeGB: Double {
    Double(size) / 1_073_741_824
  }

  /// Estimated RAM needed (model size * ~1.2 overhead for KV cache).
  public var estimatedRAMGB: Double {
    sizeGB * 1.2
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
  /// Qwen3-style thinking/reasoning tokens (not shown to user).
  public let thinking: String?
}

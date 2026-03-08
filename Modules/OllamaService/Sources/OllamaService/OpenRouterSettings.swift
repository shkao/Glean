import Foundation

public struct OpenRouterSettings: Codable, Sendable {
  public var apiKey: String
  public var model: String

  private static let defaultsKey = "OpenRouterSettings"
  private static let envVarKey = "OPENROUTER_API_KEY"

  public static let defaultModel = "qwen/qwen3.5-flash-02-23"

  public init(
    apiKey: String = "",
    model: String = OpenRouterSettings.defaultModel
  ) {
    self.apiKey = apiKey
    self.model = model
  }

  /// Loads settings from UserDefaults, with env var fallback for the API key.
  public static func load() -> OpenRouterSettings {
    var settings: OpenRouterSettings
    if let data = UserDefaults.standard.data(forKey: defaultsKey),
       let decoded = try? JSONDecoder().decode(OpenRouterSettings.self, from: data) {
      settings = decoded
    } else {
      settings = OpenRouterSettings()
    }

    // Fall back to env var if no API key is stored
    if settings.apiKey.isEmpty,
       let envKey = ProcessInfo.processInfo.environment[envVarKey], !envKey.isEmpty {
      settings.apiKey = envKey
    }

    return settings
  }

  /// Persists settings to UserDefaults.
  public func save() {
    guard let data = try? JSONEncoder().encode(self) else { return }
    UserDefaults.standard.set(data, forKey: Self.defaultsKey)
  }

  public var isConfigured: Bool {
    !apiKey.isEmpty
  }
}

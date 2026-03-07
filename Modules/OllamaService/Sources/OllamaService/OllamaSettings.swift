import Foundation

public struct OllamaSettings: Codable, Sendable {
  public var baseURL: String
  public var preferredModel: String

  private static let defaultsKey = "OllamaSettings"

  public init(
    baseURL: String = "http://localhost:11434",
    preferredModel: String = "llama3.2"
  ) {
    self.baseURL = baseURL
    self.preferredModel = preferredModel
  }

  /// Loads settings from UserDefaults, falling back to defaults.
  public static func load() -> OllamaSettings {
    guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
      return OllamaSettings()
    }
    do {
      return try JSONDecoder().decode(OllamaSettings.self, from: data)
    } catch {
      return OllamaSettings()
    }
  }

  /// Persists settings to UserDefaults.
  public func save() {
    guard let data = try? JSONEncoder().encode(self) else { return }
    UserDefaults.standard.set(data, forKey: Self.defaultsKey)
  }
}

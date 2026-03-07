import Foundation
import Testing
@testable import OllamaService

@Suite("OllamaModels")
struct OllamaModelsTests {

	@Test("OllamaGenerateRequest encodes correctly")
	func generateRequestEncoding() throws {
		let request = OllamaGenerateRequest(
			model: "llama3.2",
			prompt: "Hello",
			system: "Be helpful",
			stream: true
		)

		let data = try JSONEncoder().encode(request)
		let dict = try JSONDecoder().decode([String: AnyCodable].self, from: data)

		#expect(dict["model"]?.stringValue == "llama3.2")
		#expect(dict["prompt"]?.stringValue == "Hello")
		#expect(dict["system"]?.stringValue == "Be helpful")
		#expect(dict["stream"]?.boolValue == true)
	}

	@Test("OllamaGenerateRequest encodes without system prompt")
	func generateRequestNoSystem() throws {
		let request = OllamaGenerateRequest(
			model: "llama3.2",
			prompt: "Hello",
			system: nil,
			stream: false
		)

		let data = try JSONEncoder().encode(request)
		let json = String(data: data, encoding: .utf8) ?? ""
		#expect(json.contains("\"stream\":false"))
	}

	@Test("OllamaGenerateResponse decodes correctly")
	func generateResponseDecoding() throws {
		let json = """
		{"model":"llama3.2","response":"Hello!","done":false}
		"""
		let data = Data(json.utf8)
		let response = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)

		#expect(response.model == "llama3.2")
		#expect(response.response == "Hello!")
		#expect(response.done == false)
	}

	@Test("OllamaTagsResponse decodes model list")
	func tagsResponseDecoding() throws {
		let json = """
		{
			"models": [
				{"name": "llama3.2", "modified_at": "2024-01-01T00:00:00Z", "size": 1000000}
			]
		}
		"""
		let data = Data(json.utf8)
		let response = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)

		#expect(response.models.count == 1)
		#expect(response.models[0].name == "llama3.2")
		#expect(response.models[0].size == 1000000)
	}

	@Test("OllamaModel decodes snake_case modified_at")
	func modelDecodingSnakeCase() throws {
		let json = """
		{"name": "phi3", "modified_at": "2024-06-15T12:00:00Z", "size": 500000}
		"""
		let data = Data(json.utf8)
		let model = try JSONDecoder().decode(OllamaModel.self, from: data)

		#expect(model.name == "phi3")
		#expect(model.modifiedAt == "2024-06-15T12:00:00Z")
	}
}

@Suite("OllamaSettings")
struct OllamaSettingsTests {

	@Test("Default settings have expected values")
	func defaultSettings() {
		let settings = OllamaSettings()
		#expect(settings.baseURL == "http://localhost:11434")
		#expect(settings.preferredModel == "llama3.2")
	}

	@Test("Settings round-trip through Codable")
	func settingsCodableRoundTrip() throws {
		let original = OllamaSettings(baseURL: "http://192.168.1.100:11434", preferredModel: "mistral")
		let data = try JSONEncoder().encode(original)
		let decoded = try JSONDecoder().decode(OllamaSettings.self, from: data)

		#expect(decoded.baseURL == original.baseURL)
		#expect(decoded.preferredModel == original.preferredModel)
	}
}

@Suite("ArticleTagger")
struct ArticleTaggerTests {

	@Test("Tag parsing splits comma-separated values")
	func tagParsing() {
		let response = "Technology, AI, Machine Learning, Ethics"
		let tags = response
			.split(separator: ",")
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }

		#expect(tags == ["Technology", "AI", "Machine Learning", "Ethics"])
	}

	@Test("Tag parsing handles whitespace-only entries")
	func tagParsingWhitespace() {
		let response = "Science, , Biology, "
		let tags = response
			.split(separator: ",")
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }

		#expect(tags == ["Science", "Biology"])
	}
}

// Minimal helper for JSON dictionary decoding in tests
private struct AnyCodable: Codable {
	let value: Any

	var stringValue: String? { value as? String }
	var boolValue: Bool? { value as? Bool }

	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		if let str = try? container.decode(String.self) {
			value = str
		} else if let bool = try? container.decode(Bool.self) {
			value = bool
		} else if let int = try? container.decode(Int.self) {
			value = int
		} else {
			value = ""
		}
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		if let str = value as? String {
			try container.encode(str)
		}
	}
}

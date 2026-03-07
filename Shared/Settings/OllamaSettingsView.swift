//
//  OllamaSettingsView.swift
//  Glean
//
//  Settings pane for configuring the Ollama LLM connection.
//  Used on both macOS (Preferences) and iOS (Settings).
//

import SwiftUI
import OllamaService

struct OllamaSettingsView: View {

	@State private var baseURL: String
	@State private var preferredModel: String
	@State private var isAvailable: Bool?
	@State private var availableModels: [OllamaModel] = []
	@State private var isChecking = false

	init() {
		let settings = OllamaSettings.load()
		_baseURL = State(initialValue: settings.baseURL)
		_preferredModel = State(initialValue: settings.preferredModel)
	}

	var body: some View {
		Form {
			Section("Connection") {
				TextField("Server URL", text: $baseURL)
					.textFieldStyle(.roundedBorder)
					.autocorrectionDisabled()
				#if os(iOS)
					.textInputAutocapitalization(.never)
					.keyboardType(.URL)
				#endif
					.onChange(of: baseURL) {
						isAvailable = nil
					}

				HStack {
					Button("Check Connection") {
						Task { await checkConnection() }
					}
					.disabled(isChecking)

					if isChecking {
						ProgressView()
							.controlSize(.small)
					} else if let isAvailable {
						Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
							.foregroundColor(isAvailable ? .green : .red)
						Text(isAvailable ? "Connected" : "Not reachable")
							.foregroundColor(.secondary)
					}
				}
			}

			Section("Model") {
				if availableModels.isEmpty {
					TextField("Model name", text: $preferredModel)
						.textFieldStyle(.roundedBorder)
				} else {
					Picker("Model", selection: $preferredModel) {
						ForEach(availableModels, id: \.name) { model in
							Text(model.name).tag(model.name)
						}
					}
				}
			}

			Section {
				Button("Save") {
					save()
				}
				.buttonStyle(.borderedProminent)
			}
		}
		.padding()
		.navigationTitle("Ollama")
	}

	private func checkConnection() async {
		isChecking = true
		defer { isChecking = false }

		let client = OllamaClient(baseURL: baseURL)
		let available = await client.checkAvailability()
		isAvailable = available

		if available {
			if let models = try? await client.listModels() {
				availableModels = models
				if !models.isEmpty && !models.contains(where: { $0.name == preferredModel }) {
					preferredModel = models[0].name
				}
			}
		} else {
			availableModels = []
		}
	}

	private func save() {
		let settings = OllamaSettings(baseURL: baseURL, preferredModel: preferredModel)
		settings.save()
	}
}

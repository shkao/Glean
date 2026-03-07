//
//  OllamaSettingsView.swift
//  Glean
//
//  Ollama connection and model settings.
//  Tab in Preferences (macOS) or row in Settings (iOS).
//

import SwiftUI

struct OllamaSettingsView: View {

	@State private var serverURL = "http://localhost:11434"
	@State private var modelName = "llama3.2"
	@State private var availableModels: [String] = []
	@State private var connectionStatus: ConnectionStatus = .idle
	@State private var isCheckingConnection = false

	var body: some View {
		Form {
			Section("Connection") {
				HStack {
					Text("Server URL")
					#if os(macOS)
						.frame(minWidth: 90, alignment: .leading)
					#endif
					TextField("http://localhost:11434", text: $serverURL)
						.font(.system(.body, design: .monospaced))
						.autocorrectionDisabled()
						#if os(iOS)
						.keyboardType(.URL)
						.textInputAutocapitalization(.never)
						#endif
				}

				HStack {
					Button("Check Connection") {
						checkConnection()
					}
					.disabled(isCheckingConnection)

					Spacer()

					connectionStatusView
				}
			}

			Section("Model") {
				if availableModels.isEmpty {
					HStack {
						Text("Model")
						#if os(macOS)
							.frame(minWidth: 90, alignment: .leading)
						#endif
						TextField("Model name", text: $modelName)
							.font(.system(.body, design: .monospaced))
							.autocorrectionDisabled()
							#if os(iOS)
							.textInputAutocapitalization(.never)
							#endif
					}
				} else {
					Picker("Model", selection: $modelName) {
						ForEach(availableModels, id: \.self) { model in
							Text(model).tag(model)
						}
					}
				}
			}

			Section {
				Button {
					// Save settings in real implementation
				} label: {
					Text("Save")
						.frame(maxWidth: .infinity)
				}
				.buttonStyle(.borderedProminent)
				#if os(iOS)
				.listRowInsets(EdgeInsets())
				.listRowBackground(Color.clear)
				#endif
			}
		}
		.navigationTitle("Ollama")
		#if os(iOS)
		.navigationBarTitleDisplayMode(.inline)
		#endif
	}

	// MARK: - Connection Status

	@ViewBuilder
	private var connectionStatusView: some View {
		switch connectionStatus {
		case .idle:
			EmptyView()
		case .checking:
			ProgressView()
				.controlSize(.small)
		case .connected:
			Label("Connected", systemImage: "checkmark.circle.fill")
				.font(.subheadline)
				.foregroundStyle(.green)
		case .failed:
			Label("Not reachable", systemImage: "xmark.circle.fill")
				.font(.subheadline)
				.foregroundStyle(.red)
		}
	}

	// MARK: - Simulation

	private func checkConnection() {
		isCheckingConnection = true
		connectionStatus = .checking
		Task {
			try? await Task.sleep(for: .seconds(1))
			// Simulate a successful connection with models
			connectionStatus = .connected
			availableModels = ["llama3.2", "mistral", "phi3"]
			isCheckingConnection = false
		}
	}
}

private enum ConnectionStatus {
	case idle, checking, connected, failed
}

// MARK: - Previews

#Preview("Ollama Settings - Initial") {
	NavigationStack {
		OllamaSettingsView()
	}
}

#Preview("Ollama Settings - iOS Style") {
	NavigationStack {
		OllamaSettingsView()
	}
}

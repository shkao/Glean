//
//  OpenRouterSettingsView.swift
//  Glean
//
//  Settings pane for configuring the OpenRouter API connection.
//

import SwiftUI
import OllamaService

struct OpenRouterSettingsView: View {

  @State private var apiKey: String
  @State private var model: String
  @State private var isChecking = false
  @State private var isAvailable: Bool?

  init() {
    let settings = OpenRouterSettings.load()
    _apiKey = State(initialValue: settings.apiKey)
    _model = State(initialValue: settings.model)
  }

  var body: some View {
    Form {
      Section("API Key") {
        SecureField("OpenRouter API Key", text: $apiKey)
          .textFieldStyle(.roundedBorder)

        HStack {
          Button("Check Connection") {
            Task { await checkConnection() }
          }
          .disabled(isChecking || apiKey.isEmpty)

          if isChecking {
            ProgressView()
              .controlSize(.small)
          } else if let isAvailable {
            Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
              .foregroundColor(isAvailable ? .green : .red)
            Text(isAvailable ? "Connected" : "Invalid key or unreachable")
              .foregroundColor(.secondary)
          }
        }
      }

      Section("Model") {
        TextField("Model identifier", text: $model)
          .textFieldStyle(.roundedBorder)
        Text("e.g. qwen/qwen3.5-flash-02-23")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section {
        Button("Save") {
          save()
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding()
    .navigationTitle("OpenRouter")
  }

  private func checkConnection() async {
    isChecking = true
    defer { isChecking = false }

    let client = OpenRouterClient(apiKey: apiKey, model: model)
    isAvailable = await client.checkAvailability()
  }

  private func save() {
    let settings = OpenRouterSettings(apiKey: apiKey, model: model)
    settings.save()
  }
}

//
//  ImportURLsView.swift
//  Glean
//
//  Chrome tab / clipboard URL import: paste text, extract URLs, import.
//

import SwiftUI
import Account

struct ImportURLsView: View {

	@Environment(\.dismiss) private var dismiss
	var onDismiss: (() -> Void)?
	@State private var inputText = ""
	@State private var extractedURLs: [URL] = []
	@State private var isImporting = false
	@State private var importProgress = 0
	@State private var importTotal = 0
	@State private var importResult: ImportResult?

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Button("Cancel") { close() }
					.buttonStyle(.borderless)
				Spacer()
				Text("Import URLs")
					.font(.headline)
				Spacer()
				Button("Cancel") { }
					.buttonStyle(.borderless)
					.hidden()
			}
			.padding()

			Divider()

			if let result = importResult {
				resultView(result)
			} else {
				inputAndPreview
			}
		}
		#if os(macOS)
		.frame(width: 500, height: 480)
		#endif
	}

	private var inputAndPreview: some View {
		VStack(spacing: 0) {
			// Input area
			VStack(alignment: .leading, spacing: 8) {
				HStack {
					Label("Paste URLs or text containing URLs", systemImage: "doc.on.clipboard")
						.font(.subheadline.bold())
					Spacer()
					Button("Paste from Clipboard") {
						pasteFromClipboard()
					}
					.buttonStyle(.bordered)
					.controlSize(.small)
				}

				TextEditor(text: $inputText)
					.font(.system(.body, design: .monospaced))
					.frame(minHeight: 120, maxHeight: 160)
					.overlay(
						RoundedRectangle(cornerRadius: 8)
							.stroke(.quaternary)
					)
					.onChange(of: inputText) {
						extractURLsFromInput()
					}
			}
			.padding()

			Divider()

			// URL preview
			if extractedURLs.isEmpty && !inputText.isEmpty {
				ContentUnavailableView {
					Label("No URLs Found", systemImage: "link.badge.plus")
				} description: {
					Text("Paste text containing HTTP or HTTPS URLs.")
				}
			} else if extractedURLs.isEmpty {
				ContentUnavailableView {
					Label("Paste URLs", systemImage: "arrow.down.doc")
				} description: {
					Text("Copy your Chrome tabs and paste them here,\nor enter URLs one per line.")
				}
			} else {
				List {
					Section {
						ForEach(extractedURLs, id: \.absoluteString) { url in
							HStack(spacing: 10) {
								Image(systemName: "link")
									.foregroundStyle(.blue)
									.font(.caption)
								VStack(alignment: .leading, spacing: 1) {
									Text(url.host ?? "")
										.font(.subheadline.bold())
										.lineLimit(1)
									Text(url.path)
										.font(.caption)
										.foregroundStyle(.secondary)
										.lineLimit(1)
								}
							}
							.padding(.vertical, 2)
						}
					} header: {
						Text("\(extractedURLs.count) URLs detected")
					}
				}
				.listStyle(.plain)
			}

			Divider()

			// Action bar
			HStack {
				if isImporting {
					ProgressView()
						.controlSize(.small)
					Text("Importing \(importProgress) of \(importTotal)...")
						.foregroundStyle(.secondary)
						.font(.subheadline)
				} else {
					Text("\(extractedURLs.count) URLs ready to import")
						.foregroundStyle(.secondary)
						.font(.subheadline)
				}
				Spacer()
				Button("Import All") {
					performImport()
				}
				.buttonStyle(.borderedProminent)
				.disabled(extractedURLs.isEmpty || isImporting)
			}
			.padding()
			.background(.bar)
		}
	}

	private func resultView(_ result: ImportResult) -> some View {
		VStack(spacing: 24) {
			Spacer()

			Image(systemName: result.failed > 0 ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
				.font(.system(size: 56))
				.foregroundStyle(result.failed > 0 ? .orange : .green)

			VStack(spacing: 8) {
				Text("Import Complete")
					.font(.title2.bold())

				if result.failed > 0 {
					Text("\(result.imported) imported, \(result.failed) failed")
						.foregroundStyle(.secondary)
				} else {
					Text("\(result.imported) articles imported to Saved Pages.")
						.foregroundStyle(.secondary)
				}
			}

			Button("Done") { close() }
				.buttonStyle(.borderedProminent)
				.controlSize(.large)

			Spacer()
		}
		.padding()
	}

	// MARK: - Actions

	private func close() {
		if let onDismiss {
			onDismiss()
		} else {
			dismiss()
		}
	}

	private func pasteFromClipboard() {
		#if os(macOS)
		if let string = NSPasteboard.general.string(forType: .string) {
			inputText = string
		}
		#else
		if let string = UIPasteboard.general.string {
			inputText = string
		}
		#endif
	}

	private func extractURLsFromInput() {
		extractedURLs = URLExtractor.extractURLs(from: inputText)
	}

	private func performImport() {
		isImporting = true
		importTotal = extractedURLs.count
		importProgress = 0

		Task {
			let account = AccountManager.savedPagesAccount()
			let importer = BulkURLImporter()
			let result = await importer.importURLs(extractedURLs, to: account, folder: nil) { completed, total in
				importProgress = completed
				importTotal = total
			}
			importResult = ImportResult(imported: result.imported, failed: result.failed)
			isImporting = false
		}
	}

}

private struct ImportResult {
	let imported: Int
	let failed: Int
}

// MARK: - Previews

#Preview("Import URLs - Empty") {
	ImportURLsView()
}

#Preview("Import URLs - With Content") {
	ImportURLsView()
}

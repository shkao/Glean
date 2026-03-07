//
//  ImportScreenshotView.swift
//  Glean
//
//  Screenshot import flow: select photos, OCR for URLs, preview, import.
//

import SwiftUI

struct ImportScreenshotView: View {

	@Environment(\.dismiss) private var dismiss
	var onDismiss: (() -> Void)?
	@State private var phase: ImportPhase = .selectPhotos
	@State private var extractedURLs: [ExtractedURL] = []
	@State private var selectedURLs: Set<String> = []
	@State private var isProcessing = false
	@State private var progress: Double = 0

	var body: some View {
		VStack(spacing: 0) {
			// Title bar with Cancel
			HStack {
				Button("Cancel") { close() }
					.buttonStyle(.borderless)
				Spacer()
				Text("Import from Screenshots")
					.font(.headline)
				Spacer()
				// Balance the Cancel button width
				Button("Cancel") { }
					.buttonStyle(.borderless)
					.hidden()
			}
			.padding()

			Divider()

			switch phase {
			case .selectPhotos:
				selectPhotosView
			case .processing:
				processingView
			case .reviewURLs:
				reviewURLsView
			case .importing:
				importingView
			case .done(let count):
				doneView(count: count)
			}
		}
		#if os(macOS)
		.frame(width: 480, height: 520)
		#endif
	}

	// MARK: - Phase Views

	private var selectPhotosView: some View {
		VStack(spacing: 24) {
			Spacer()

			Image(systemName: "photo.on.rectangle.angled")
				.font(.system(size: 56))
				.foregroundStyle(.secondary)

			VStack(spacing: 8) {
				Text("Select Screenshots")
					.font(.title2.bold())
				Text("Glean will scan your screenshots for URLs\nand import them as articles.")
					.multilineTextAlignment(.center)
					.foregroundStyle(.secondary)
			}

			Button {
				// PHPickerViewController presented here in real implementation
				phase = .processing
				simulateOCR()
			} label: {
				Label("Choose Photos", systemImage: "photo.badge.plus")
					.frame(maxWidth: 200)
			}
			.buttonStyle(.borderedProminent)
			.controlSize(.large)

			Spacer()
		}
		.padding()
	}

	private var processingView: some View {
		VStack(spacing: 24) {
			Spacer()

			ProgressView(value: progress) {
				Text("Scanning screenshots...")
					.font(.headline)
			} currentValueLabel: {
				Text("\(Int(progress * 100))%")
					.foregroundStyle(.secondary)
			}
			.progressViewStyle(.linear)
			.frame(maxWidth: 300)

			Text("Using on-device text recognition")
				.font(.caption)
				.foregroundStyle(.tertiary)

			Spacer()
		}
		.padding()
	}

	private var reviewURLsView: some View {
		VStack(spacing: 0) {
			// Header stats
			HStack {
				Label("\(extractedURLs.count) URLs found", systemImage: "link")
					.font(.subheadline.bold())
				Spacer()
				Button("Select All") {
					selectedURLs = Set(extractedURLs.map(\.id))
				}
				.buttonStyle(.borderless)
				.font(.subheadline)
			}
			.padding()
			.background(.bar)

			Divider()

			// URL list
			List(extractedURLs, selection: $selectedURLs) { url in
				URLRowView(extractedURL: url, isSelected: selectedURLs.contains(url.id))
					.contentShape(Rectangle())
					.onTapGesture {
						if selectedURLs.contains(url.id) {
							selectedURLs.remove(url.id)
						} else {
							selectedURLs.insert(url.id)
						}
					}
			}
			.listStyle(.plain)

			Divider()

			// Action bar
			HStack {
				Text("\(selectedURLs.count) selected")
					.foregroundStyle(.secondary)
					.font(.subheadline)
				Spacer()
				Button("Import Selected") {
					phase = .importing
					simulateImport()
				}
				.buttonStyle(.borderedProminent)
				.disabled(selectedURLs.isEmpty)
			}
			.padding()
			.background(.bar)
		}
	}

	private var importingView: some View {
		VStack(spacing: 24) {
			Spacer()

			ProgressView(value: progress) {
				Text("Importing articles...")
					.font(.headline)
			} currentValueLabel: {
				Text("\(Int(progress * Double(selectedURLs.count))) of \(selectedURLs.count)")
					.foregroundStyle(.secondary)
			}
			.progressViewStyle(.linear)
			.frame(maxWidth: 300)

			Text("Fetching and extracting content")
				.font(.caption)
				.foregroundStyle(.tertiary)

			Spacer()
		}
		.padding()
	}

	private func doneView(count: Int) -> some View {
		VStack(spacing: 24) {
			Spacer()

			Image(systemName: "checkmark.circle.fill")
				.font(.system(size: 56))
				.foregroundStyle(.green)

			VStack(spacing: 8) {
				Text("Import Complete")
					.font(.title2.bold())
				Text("\(count) articles imported to Saved Pages.")
					.foregroundStyle(.secondary)
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

	// MARK: - Preview Simulation

	private func simulateOCR() {
		Task {
			for i in 1...10 {
				try? await Task.sleep(for: .milliseconds(100))
				progress = Double(i) / 10.0
			}
			extractedURLs = ExtractedURL.sampleData
			selectedURLs = Set(extractedURLs.map(\.id))
			phase = .reviewURLs
			progress = 0
		}
	}

	private func simulateImport() {
		Task {
			let total = selectedURLs.count
			for i in 1...total {
				try? await Task.sleep(for: .milliseconds(300))
				progress = Double(i) / Double(total)
			}
			phase = .done(total)
		}
	}
}

// MARK: - Supporting Types

private enum ImportPhase: Equatable {
	case selectPhotos
	case processing
	case reviewURLs
	case importing
	case done(Int)
}

struct ExtractedURL: Identifiable {
	let id: String
	let url: URL
	let sourceImage: Int // which screenshot it came from

	var displayHost: String {
		url.host ?? url.absoluteString
	}

	var displayPath: String {
		let path = url.path
		return path.isEmpty || path == "/" ? "" : path
	}

	static let sampleData: [ExtractedURL] = [
		ExtractedURL(id: "1", url: URL(string: "https://arxiv.org/abs/2401.12345")!, sourceImage: 1),
		ExtractedURL(id: "2", url: URL(string: "https://simonwillison.net/2024/Jan/15/llm-reasoning/")!, sourceImage: 1),
		ExtractedURL(id: "3", url: URL(string: "https://www.nature.com/articles/s41586-024-07042-3")!, sourceImage: 2),
		ExtractedURL(id: "4", url: URL(string: "https://github.com/ggerganov/llama.cpp/releases/tag/b2100")!, sourceImage: 2),
		ExtractedURL(id: "5", url: URL(string: "https://blog.pragmaticengineer.com/ai-coding-tools/")!, sourceImage: 3),
	]
}

private struct URLRowView: View {
	let extractedURL: ExtractedURL
	let isSelected: Bool

	var body: some View {
		HStack(spacing: 12) {
			Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
				.foregroundStyle(isSelected ? .blue : .secondary)
				.font(.title3)

			VStack(alignment: .leading, spacing: 2) {
				Text(extractedURL.displayHost)
					.font(.subheadline.bold())
					.lineLimit(1)
				if !extractedURL.displayPath.isEmpty {
					Text(extractedURL.displayPath)
						.font(.caption)
						.foregroundStyle(.secondary)
						.lineLimit(1)
				}
			}

			Spacer()

			Label("Screenshot \(extractedURL.sourceImage)", systemImage: "photo")
				.font(.caption2)
				.foregroundStyle(.tertiary)
		}
		.padding(.vertical, 4)
	}
}

// MARK: - Previews

#Preview("Screenshot Import - Select") {
	ImportScreenshotView()
}

#Preview("Screenshot Import - Review") {
	let view = ImportScreenshotView()
	return view
}

//
//  ImportScreenshotView.swift
//  Glean
//
//  Screenshot import flow: scan Photos library for web page screenshots,
//  find original URLs via OCR + web search, import to Saved Pages.
//

import SwiftUI
import Photos
import Account

extension AccountManager {
	/// Returns the SavedPages account, creating one if needed.
	@MainActor static func savedPagesAccount() -> Account {
		let manager = AccountManager.shared
		if let existing = manager.activeAccounts.first(where: { $0.type == .savedPages }) {
			return existing
		}
		return manager.createAccount(type: .savedPages)
	}
}

struct ImportScreenshotView: View {

	@Environment(\.dismiss) private var dismiss
	var onDismiss: (() -> Void)?

	@State private var phase: ImportPhase = .requestAccess
	@State private var detectedPages: [DetectedWebPage] = []
	@State private var selectedIDs: Set<String> = []
	@State private var scanProgress: ScanProgress = ScanProgress()
	@State private var importProgress = 0
	@State private var importResult: ImportSummary?
	@State private var deleteAfterImport = true

	var body: some View {
		VStack(spacing: 0) {
			titleBar
			Divider()

			switch phase {
			case .requestAccess:
				requestAccessView
			case .scanning:
				scanningView
			case .noResults:
				noResultsView
			case .review:
				reviewView
			case .importing:
				importingView
			case .done:
				doneView
			}
		}
		#if os(macOS)
		.frame(width: 520, height: 560)
		#endif
		.task {
			let status = PhotosScreenshotScanner.authorizationStatus
			if status == .authorized || status == .limited {
				phase = .scanning
				await scanScreenshots()
			}
		}
	}

	// MARK: - Title Bar

	private var titleBar: some View {
		HStack {
			Button("Cancel") { close() }
				.buttonStyle(.borderless)
			Spacer()
			Text("Import from Screenshots")
				.font(.headline)
			Spacer()
			Button("Cancel") { }
				.buttonStyle(.borderless)
				.hidden()
		}
		.padding()
	}

	// MARK: - Request Access

	private var requestAccessView: some View {
		VStack(spacing: 24) {
			Spacer()

			Image(systemName: "photo.on.rectangle.angled")
				.font(.system(size: 56))
				.foregroundStyle(.secondary)

			VStack(spacing: 8) {
				Text("Photos Access Required")
					.font(.title2.bold())
				Text("Glean scans your recent screenshots for web pages\nand imports them as saved articles.")
					.multilineTextAlignment(.center)
					.foregroundStyle(.secondary)
			}

			Button {
				Task {
					let status = await PhotosScreenshotScanner.requestAuthorization()
					if status == .authorized || status == .limited {
						phase = .scanning
						await scanScreenshots()
					}
				}
			} label: {
				Label("Grant Access", systemImage: "photo.badge.checkmark")
					.frame(maxWidth: 200)
			}
			.buttonStyle(.borderedProminent)
			.controlSize(.large)

			Spacer()
		}
		.padding()
	}

	// MARK: - Scanning

	private var scanningView: some View {
		VStack(spacing: 24) {
			Spacer()

			ProgressView(value: scanProgress.fraction) {
				Text(scanProgress.statusText)
					.font(.headline)
			} currentValueLabel: {
				Text(scanProgress.detailText)
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

	// MARK: - No Results

	private var noResultsView: some View {
		VStack(spacing: 24) {
			Spacer()

			Image(systemName: "photo.badge.magnifyingglass")
				.font(.system(size: 56))
				.foregroundStyle(.secondary)

			VStack(spacing: 8) {
				Text("No Web Pages Found")
					.font(.title2.bold())
				Text("No recent screenshots appear to be web articles.\nTry taking screenshots of articles you want to save.")
					.multilineTextAlignment(.center)
					.foregroundStyle(.secondary)
			}

			Button("Done") { close() }
				.buttonStyle(.borderedProminent)
				.controlSize(.large)

			Spacer()
		}
		.padding()
	}

	// MARK: - Review

	private var reviewView: some View {
		VStack(spacing: 0) {
			HStack {
				Label("\(detectedPages.count) web pages found", systemImage: "globe")
					.font(.subheadline.bold())
				Spacer()
				Button(selectedIDs.count == detectedPages.count ? "Deselect All" : "Select All") {
					if selectedIDs.count == detectedPages.count {
						selectedIDs.removeAll()
					} else {
						selectedIDs = Set(detectedPages.map(\.id))
					}
				}
				.buttonStyle(.borderless)
				.font(.subheadline)
			}
			.padding()
			.background(.bar)

			Divider()

			List {
				ForEach(detectedPages) { page in
					DetectedPageRow(page: page, isSelected: selectedIDs.contains(page.id))
						.contentShape(Rectangle())
						.onTapGesture {
							if selectedIDs.contains(page.id) {
								selectedIDs.remove(page.id)
							} else {
								selectedIDs.insert(page.id)
							}
						}
				}
			}
			.listStyle(.plain)

			Divider()

			HStack {
				Toggle("Delete screenshots after import", isOn: $deleteAfterImport)
					.font(.subheadline)
					.toggleStyle(.checkbox)
				Spacer()
				Text("\(selectedIDs.count) selected")
					.foregroundStyle(.secondary)
					.font(.subheadline)
				Button("Import Selected") {
					performImport()
				}
				.buttonStyle(.borderedProminent)
				.disabled(selectedIDs.isEmpty)
			}
			.padding()
			.background(.bar)
		}
	}

	// MARK: - Importing

	private var importingView: some View {
		VStack(spacing: 24) {
			Spacer()

			ProgressView(value: Double(importProgress), total: Double(selectedIDs.count)) {
				Text("Importing articles...")
					.font(.headline)
			} currentValueLabel: {
				Text("\(importProgress) of \(selectedIDs.count)")
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

	// MARK: - Done

	private var doneView: some View {
		VStack(spacing: 24) {
			Spacer()

			Image(systemName: importResult?.failed ?? 0 > 0 ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
				.font(.system(size: 56))
				.foregroundStyle(importResult?.failed ?? 0 > 0 ? .orange : .green)

			VStack(spacing: 8) {
				Text("Import Complete")
					.font(.title2.bold())

				if let result = importResult {
					if result.failed > 0 {
						Text("\(result.imported) imported, \(result.failed) failed")
							.foregroundStyle(.secondary)
					} else {
						Text("\(result.imported) articles imported to Saved Pages.")
							.foregroundStyle(.secondary)
					}
					if result.screenshotsDeleted > 0 {
						Text("\(result.screenshotsDeleted) screenshots removed from Photos.")
							.foregroundStyle(.tertiary)
							.font(.caption)
					}
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

	private func scanScreenshots() async {
		let scanner = PhotosScreenshotScanner()
		let importer = ScreenshotImporter()

		scanProgress = ScanProgress(phase: "Fetching screenshots...")
		let assets = scanner.fetchRecentScreenshots(limit: 50, daysBack: 30)

		if assets.isEmpty {
			phase = .noResults
			return
		}

		scanProgress = ScanProgress(phase: "Scanning \(assets.count) screenshots...", total: assets.count)

		var completed = 0
		var pages: [DetectedWebPage] = []

		// Process screenshots concurrently (max 4 at a time)
		await withTaskGroup(of: DetectedWebPage?.self) { group in
			var inFlight = 0
			var assetIndex = 0

			for asset in assets {
				// Throttle concurrency
				if inFlight >= 4 {
					if let result = await group.next() {
						completed += 1
						scanProgress.completed = completed
						if let page = result { pages.append(page) }
					}
					inFlight -= 1
				}

				assetIndex += 1
				inFlight += 1

				group.addTask {
					await self.processScreenshot(asset: asset, scanner: scanner, importer: importer)
				}
			}

			// Collect remaining results
			for await result in group {
				completed += 1
				scanProgress.completed = completed
				if let page = result { pages.append(page) }
			}
		}

		detectedPages = pages
		selectedIDs = Set(detectedPages.map(\.id))

		phase = detectedPages.isEmpty ? .noResults : .review
	}

	private func processScreenshot(
		asset: PHAsset,
		scanner: PhotosScreenshotScanner,
		importer: ScreenshotImporter
	) async -> DetectedWebPage? {
		guard let cgImage = await scanner.requestCGImage(for: asset) else {
			return nil
		}

		guard let analysis = try? await importer.analyzeScreenshot(cgImage),
			  analysis.isLikelyWebContent else {
			return nil
		}

		// Strategy 1: Direct URL from OCR text
		if let directURL = analysis.directURLs.first {
			let thumbnail = await scanner.requestThumbnail(for: asset)
			return DetectedWebPage(
				asset: asset,
				thumbnail: thumbnail,
				title: analysis.detectedTitle ?? directURL.host ?? "Web Page",
				url: directURL,
				domain: directURL.host ?? "",
				confidence: .high,
				source: .directURL
			)
		}

		// Strategy 2: Search by title + domain
		if let title = analysis.detectedTitle {
			let searcher = WebSearcher()
			let foundURL = await searcher.findArticleURL(
				title: title,
				domain: analysis.detectedDomain
			)
			if let url = foundURL {
				let thumbnail = await scanner.requestThumbnail(for: asset)
				let conf: DetectedWebPage.Confidence = analysis.detectedDomain != nil ? .high : .medium
				return DetectedWebPage(
					asset: asset,
					thumbnail: thumbnail,
					title: title,
					url: url,
					domain: url.host ?? analysis.detectedDomain ?? "",
					confidence: conf,
					source: .webSearch
				)
			}
		}

		return nil
	}

	private func performImport() {
		phase = .importing
		importProgress = 0

		Task {
			let account = AccountManager.savedPagesAccount()
			let bulkImporter = BulkURLImporter()
			let selectedPages = detectedPages.filter { selectedIDs.contains($0.id) }
			let urls = selectedPages.map(\.url)

			// Track which URLs succeeded
			var importedURLs = Set<String>()
			let result = await bulkImporter.importURLs(urls, to: account, folder: nil) { completed, _ in
				importProgress = completed
				if completed > importedURLs.count, completed <= urls.count {
					importedURLs.insert(urls[completed - 1].absoluteString)
				}
			}

			var screenshotsDeleted = 0
			if deleteAfterImport && result.imported > 0 {
				// Delete only screenshots whose URLs actually imported
				let assetsToDelete = selectedPages
					.filter { importedURLs.contains($0.url.absoluteString) }
					.map(\.asset)
				if !assetsToDelete.isEmpty {
					do {
						try await PhotosScreenshotScanner().deleteAssets(assetsToDelete)
						screenshotsDeleted = assetsToDelete.count
					} catch {
						// Deletion is optional; user may deny the system prompt
					}
				}
			}

			importResult = ImportSummary(
				imported: result.imported,
				failed: result.failed,
				screenshotsDeleted: screenshotsDeleted
			)
			phase = .done
		}
	}
}

// MARK: - Supporting Types

private enum ImportPhase {
	case requestAccess
	case scanning
	case noResults
	case review
	case importing
	case done
}

private struct ScanProgress {
	var phase: String = ""
	var completed: Int = 0
	var total: Int = 0

	var fraction: Double {
		guard total > 0 else { return 0 }
		return Double(completed) / Double(total)
	}

	var statusText: String {
		phase
	}

	var detailText: String {
		guard total > 0 else { return "" }
		return "\(completed) of \(total)"
	}
}

private struct ImportSummary {
	let imported: Int
	let failed: Int
	let screenshotsDeleted: Int
}

struct DetectedWebPage: Identifiable {
	let id = UUID().uuidString
	let asset: PHAsset
	let thumbnail: CGImage?
	let title: String
	let url: URL
	let domain: String
	let confidence: Confidence
	let source: Source

	enum Confidence: Comparable {
		case low, medium, high

		var label: String {
			switch self {
			case .low: return "Low"
			case .medium: return "Medium"
			case .high: return "High"
			}
		}

		var color: Color {
			switch self {
			case .low: return .red
			case .medium: return .orange
			case .high: return .green
			}
		}
	}

	enum Source {
		case directURL
		case webSearch
	}
}

private struct DetectedPageRow: View {
	let page: DetectedWebPage
	let isSelected: Bool

	var body: some View {
		HStack(spacing: 12) {
			Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
				.foregroundStyle(isSelected ? .blue : .secondary)
				.font(.title3)

			if let thumbnail = page.thumbnail {
				Image(decorative: thumbnail, scale: 2.0, orientation: .up)
					.resizable()
					.aspectRatio(contentMode: .fill)
					.frame(width: 40, height: 54)
					.clipShape(RoundedRectangle(cornerRadius: 4))
			}

			VStack(alignment: .leading, spacing: 2) {
				Text(page.title)
					.font(.subheadline.bold())
					.lineLimit(2)

				Text(page.domain)
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}

			Spacer()

			VStack(alignment: .trailing, spacing: 2) {
				Circle()
					.fill(page.confidence.color)
					.frame(width: 8, height: 8)

				Text(page.source == .directURL ? "URL" : "Search")
					.font(.caption2)
					.foregroundStyle(.tertiary)
			}
		}
		.padding(.vertical, 4)
	}
}

// MARK: - Previews

#Preview("Screenshot Import") {
	ImportScreenshotView()
}

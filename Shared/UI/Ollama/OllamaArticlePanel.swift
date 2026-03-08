//
//  OllamaArticlePanel.swift
//  Glean
//
//  Right sidebar: AI-native assistant panel for article summarization and Q&A.
//  Collapsed = thin tab strip. Expanded = full sidebar with card-based results.
//

import SwiftUI
import OllamaService

@MainActor
final class OllamaPanelState: ObservableObject {
	@Published var isExpanded = false
}

// MARK: - Main View

struct OllamaArticlePanel: View {

	let articleTitle: String
	let articleExcerpt: String
	@ObservedObject var panelState: OllamaPanelState

	@AppStorage("OllamaPanelFontSize") private var fontSize: Double = 13
	@AppStorage("OllamaSummaryLanguage") private var summaryLanguage: SummaryLanguage = .english
	@State private var summary = ""
	@State private var isSummarizing = false
	@State private var summaryStatus = ""
	@State private var question = ""
	@State private var chatMessages: [ChatMessage] = []
	@State private var isAnswering = false
	@State private var isOllamaAvailable = true
	@State private var errorMessage: String?
	@State private var didCopySummary = false
	@State private var didCopyAnswer = false
	@State private var showModelPicker = false
	@State private var showSettings = false
	@State private var availableModels: [OllamaModel] = []
	@State private var selectedModel: String = OllamaSettings.load().preferredModel

	private var bodyFont: SwiftUI.Font { .system(size: fontSize) }
	private var smallFont: SwiftUI.Font { .system(size: fontSize - 2) }
	private var tinyFont: SwiftUI.Font { .system(size: max(fontSize - 4, 9)) }

	private let collapsedWidth: CGFloat = 36
	private let expandedWidth: CGFloat = 300

	var body: some View {
		HStack(spacing: 0) {
			if panelState.isExpanded {
				expandedSidebar
					.frame(width: expandedWidth)
					.transition(.move(edge: .trailing))
			}

			collapsedStrip
				.frame(width: collapsedWidth)
		}
		.animation(.easeInOut(duration: 0.25), value: panelState.isExpanded)
	}

	// MARK: - Collapsed Strip

	private var collapsedStrip: some View {
		Button {
			withAnimation(.easeInOut(duration: 0.25)) {
				panelState.isExpanded.toggle()
			}
		} label: {
			VStack(spacing: 8) {
				Image(systemName: "sparkles")
					.font(.system(size: 14))
					.foregroundStyle(Color.accentColor)

				Text("AI")
					.font(.system(size: 10, weight: .semibold))
					.foregroundStyle(.secondary)

				if isSummarizing || isAnswering {
					ProgressView()
						.controlSize(.mini)
				}

				Spacer()

				Image(systemName: panelState.isExpanded ? "chevron.right" : "chevron.left")
					.font(.system(size: 9))
					.foregroundStyle(.tertiary)
			}
			.padding(.vertical, 12)
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.background(.bar)
		.help(panelState.isExpanded ? "Collapse AI sidebar" : "Expand AI sidebar")
	}

	// MARK: - Expanded Sidebar

	private var expandedSidebar: some View {
		VStack(spacing: 0) {
			sidebarHeader
			Divider()

			if !isOllamaAvailable {
				unavailableView
			} else {
				// Scrollable content area
				ScrollViewReader { proxy in
					ScrollView {
						VStack(alignment: .leading, spacing: 10) {
							summaryCard
							chatHistory
							Color.clear
								.frame(height: 1)
								.id("bottom")
						}
						.padding(10)
					}
					.onChange(of: summary) {
						if isSummarizing {
							withAnimation(.easeOut(duration: 0.15)) {
								proxy.scrollTo("bottom", anchor: .bottom)
							}
						}
					}
					.onChange(of: chatMessages.last?.answer) {
						if isAnswering {
							withAnimation(.easeOut(duration: 0.15)) {
								proxy.scrollTo("bottom", anchor: .bottom)
							}
						}
					}
				}

				Divider()

				// Pinned input bar at bottom
				askInputBar
			}
		}
		.background(.background)
	}

	// MARK: - Header

	private var sidebarHeader: some View {
		HStack(spacing: 6) {
			// Model selector (primary header element)
			Circle()
				.fill(isOllamaAvailable ? .green : .red)
				.frame(width: 6, height: 6)

			Button {
				showModelPicker.toggle()
				if showModelPicker { loadModels() }
			} label: {
				HStack(spacing: 3) {
					Text(selectedModel)
						.font(.system(size: fontSize - 2, weight: .medium))
						.lineLimit(1)

					Image(systemName: "chevron.up.chevron.down")
						.font(.system(size: 7))
						.foregroundStyle(.tertiary)
				}
			}
			.buttonStyle(.plain)
			.popover(isPresented: $showModelPicker, arrowEdge: .bottom) {
				modelPickerPopover
			}

			Spacer()

			// Settings gear (font size + info)
			Button {
				showSettings.toggle()
			} label: {
				Image(systemName: "textformat.size")
					.font(.system(size: 11))
					.foregroundStyle(.secondary)
			}
			.buttonStyle(.plain)
			.popover(isPresented: $showSettings, arrowEdge: .bottom) {
				fontSizePopover
			}
			.help("Text size")
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 7)
		.background(.bar)
	}

	private var fontSizePopover: some View {
		HStack(spacing: 12) {
			Button {
				fontSize = max(fontSize - 1, 10)
			} label: {
				Image(systemName: "minus.circle")
					.font(.body)
			}
			.buttonStyle(.plain)
			.disabled(fontSize <= 10)

			Text("\(Int(fontSize)) pt")
				.font(.system(size: 12, weight: .medium).monospacedDigit())
				.frame(width: 36)

			Button {
				fontSize = min(fontSize + 1, 20)
			} label: {
				Image(systemName: "plus.circle")
					.font(.body)
			}
			.buttonStyle(.plain)
			.disabled(fontSize >= 20)
		}
		.padding(12)
	}

	// MARK: - Summary Card

	private var summaryCard: some View {
		VStack(alignment: .leading, spacing: 8) {
			// Card header
			HStack(spacing: 4) {
				Image(systemName: "text.quote")
					.font(.system(size: 10))
					.foregroundStyle(.secondary)
				Text("Summary")
					.font(.system(size: max(fontSize - 3, 9), weight: .medium))
					.foregroundStyle(.secondary)
				Spacer()
			}

			if summary.isEmpty && !isSummarizing {
				// Compact action row
				HStack(spacing: 6) {
					languageMenu

					Button {
						runSummary()
					} label: {
						Label("Summarize", systemImage: "sparkles")
							.font(smallFont)
					}
					.buttonStyle(.borderedProminent)
					.controlSize(.small)
				}

				if let errorMessage, !isAnswering {
					errorBanner(errorMessage) { runSummary() }
				}
			} else {
				// Result
				if !summary.isEmpty {
					streamingText(summary, isStreaming: isSummarizing)
				} else if isSummarizing {
					if !summaryStatus.isEmpty {
						Text(summaryStatus)
							.font(tinyFont)
							.foregroundStyle(.secondary)
					}
					skeletonLines(count: 3)
				}

				// Inline actions after result
				if !summary.isEmpty && !isSummarizing {
					HStack(spacing: 6) {
						languageMenu

						Button {
							runSummary()
						} label: {
							Image(systemName: "arrow.clockwise")
								.font(.system(size: 10))
						}
						.buttonStyle(.plain)
						.foregroundStyle(.secondary)
						.help("Regenerate")

						Spacer()

						Button {
							copySummary(summary)
						} label: {
							Image(systemName: didCopySummary ? "checkmark" : "doc.on.doc")
								.font(.system(size: 10))
						}
						.buttonStyle(.plain)
						.foregroundStyle(didCopySummary ? Color.accentColor : .secondary)
						.help(didCopySummary ? "Copied" : "Copy")
					}
				}
			}
		}
		.padding(10)
		.background(.quaternary.opacity(0.3))
		.clipShape(RoundedRectangle(cornerRadius: 8))
	}

	// MARK: - Chat History

	@ViewBuilder
	private var chatHistory: some View {
		if !chatMessages.isEmpty {
			ForEach(chatMessages) { msg in
				chatBubble(msg)
			}
		}
	}

	private func chatBubble(_ msg: ChatMessage) -> some View {
		VStack(alignment: .leading, spacing: 6) {
			// Question
			HStack(alignment: .top, spacing: 6) {
				Image(systemName: "person.circle.fill")
					.font(.system(size: 12))
					.foregroundStyle(.secondary)
				Text(msg.question)
					.font(smallFont.weight(.medium))
					.textSelection(.enabled)
			}

			// Answer
			HStack(alignment: .top, spacing: 6) {
				Image(systemName: "sparkles")
					.font(.system(size: 12))
					.foregroundStyle(Color.accentColor)

				if !msg.answer.isEmpty {
					let isStreaming = msg.id == chatMessages.last?.id && isAnswering
					streamingText(msg.answer, isStreaming: isStreaming)
				} else if isAnswering && msg.id == chatMessages.last?.id {
					skeletonLines(count: 2)
				}
			}

			// Copy button for completed answers
			if !msg.answer.isEmpty && !(msg.id == chatMessages.last?.id && isAnswering) {
				HStack {
					Spacer()
					Button {
						copyToClipboard(msg.answer)
						didCopyAnswer = true
						DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
							didCopyAnswer = false
						}
					} label: {
						Image(systemName: didCopyAnswer ? "checkmark" : "doc.on.doc")
							.font(.system(size: 10))
					}
					.buttonStyle(.plain)
					.foregroundStyle(didCopyAnswer ? Color.accentColor : .secondary)
				}
			}
		}
		.padding(10)
		.background(.quaternary.opacity(0.3))
		.clipShape(RoundedRectangle(cornerRadius: 8))
	}

	// MARK: - Ask Input Bar

	private var askInputBar: some View {
		HStack(spacing: 6) {
			TextField("Ask about this article...", text: $question)
				.textFieldStyle(.plain)
				.font(smallFont)
				.padding(.horizontal, 8)
				.padding(.vertical, 5)
				.background(.quaternary.opacity(0.4))
				.clipShape(RoundedRectangle(cornerRadius: 6))
				.onSubmit { runAnswer() }

			Button {
				runAnswer()
			} label: {
				Image(systemName: "arrow.up.circle.fill")
					.font(.system(size: 20))
					.foregroundStyle(question.isEmpty || isAnswering ? .gray.opacity(0.3) : Color.accentColor)
			}
			.buttonStyle(.plain)
			.disabled(question.isEmpty || isAnswering)
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 8)
		.background(.bar)
	}

	// MARK: - Model Picker

	private var modelPickerPopover: some View {
		VStack(alignment: .leading, spacing: 0) {
			HStack {
				Text("Select Model")
					.font(.subheadline.weight(.semibold))
				Spacer()
				Text("\(Int(Self.systemRAMGB)) GB RAM")
					.font(.system(size: 10))
					.foregroundStyle(.secondary)
					.padding(.horizontal, 6)
					.padding(.vertical, 2)
					.background(.quaternary.opacity(0.5))
					.clipShape(RoundedRectangle(cornerRadius: 4))
			}
			.padding(.horizontal, 14)
			.padding(.top, 12)
			.padding(.bottom, 8)

			Divider()

			if availableModels.isEmpty {
				HStack(spacing: 8) {
					ProgressView().controlSize(.small)
					Text("Loading models...")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				.padding(14)
			} else {
				ScrollView {
					VStack(spacing: 2) {
						ForEach(availableModels, id: \.name) { model in
							modelRow(model)
						}
					}
					.padding(.vertical, 6)
					.padding(.horizontal, 8)
				}
				.frame(maxHeight: 280)
			}
		}
		.frame(width: 280)
	}

	private func modelRow(_ model: OllamaModel) -> some View {
		let isSelected = model.name == selectedModel
		let fit = modelFit(model)

		return Button {
			selectedModel = model.name
			var settings = OllamaSettings.load()
			settings.preferredModel = model.name
			settings.save()
			showModelPicker = false
		} label: {
			HStack(spacing: 8) {
				VStack(alignment: .leading, spacing: 2) {
					HStack(spacing: 5) {
						Text(model.name)
							.font(.caption.weight(isSelected ? .semibold : .regular))
							.foregroundStyle(.primary)
							.lineLimit(1)

						if isSelected {
							Image(systemName: "checkmark")
								.font(.system(size: 8, weight: .bold))
								.foregroundStyle(Color.accentColor)
						}
					}

					HStack(spacing: 6) {
						if let params = model.details?.parameterSize {
							Text(params)
								.font(.system(size: 10))
								.foregroundStyle(.secondary)
						}

						Text(String(format: "%.1f GB", model.sizeGB))
							.font(.system(size: 10))
							.foregroundStyle(.secondary)

						if let quant = model.details?.quantizationLevel {
							Text(quant)
								.font(.system(size: 10))
								.foregroundStyle(.tertiary)
						}
					}
				}

				Spacer()

				Text(fit.label)
					.font(.system(size: 9, weight: .medium))
					.foregroundStyle(fit.color)
					.padding(.horizontal, 6)
					.padding(.vertical, 2)
					.background(fit.color.opacity(0.12))
					.clipShape(RoundedRectangle(cornerRadius: 4))
			}
			.padding(.horizontal, 8)
			.padding(.vertical, 6)
			.background(isSelected ? Color.accentColor.opacity(0.1) : .clear)
			.clipShape(RoundedRectangle(cornerRadius: 6))
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
	}

	// MARK: - Language Menu

	private var languageMenu: some View {
		Menu {
			ForEach(SummaryLanguage.allCases) { lang in
				Button {
					summaryLanguage = lang
				} label: {
					HStack {
						Text("\(lang.flag) \(lang.label)")
						if lang == summaryLanguage {
							Spacer()
							Image(systemName: "checkmark")
						}
					}
				}
			}
		} label: {
			HStack(spacing: 3) {
				Text(summaryLanguage.flag)
					.font(.system(size: 11))
				Text(summaryLanguage.shortLabel)
					.font(.system(size: 10, weight: .medium))
				Image(systemName: "chevron.up.chevron.down")
					.font(.system(size: 7, weight: .semibold))
			}
			.foregroundStyle(.secondary)
			.padding(.horizontal, 6)
			.padding(.vertical, 3)
			.background(.quaternary.opacity(0.3))
			.clipShape(RoundedRectangle(cornerRadius: 5))
		}
		.menuStyle(.borderlessButton)
		.fixedSize()
	}

	// MARK: - Shared Components

	private func streamingText(_ text: String, isStreaming: Bool) -> some View {
		(Text(text) + (isStreaming ? Text("  \u{258C}").foregroundColor(Color.accentColor) : Text("")))
			.font(bodyFont)
			.lineSpacing(3)
			.textSelection(.enabled)
	}

	private func skeletonLines(count: Int) -> some View {
		VStack(alignment: .leading, spacing: 8) {
			ForEach(0..<count, id: \.self) { i in
				RoundedRectangle(cornerRadius: 3)
					.fill(.quaternary)
					.frame(height: fontSize * 0.8)
					.frame(maxWidth: i == count - 1 ? 120 : .infinity)
			}
		}
		.shimmering()
	}

	private func errorBanner(_ message: String, retry: @escaping () -> Void) -> some View {
		HStack(spacing: 4) {
			Image(systemName: "exclamationmark.triangle.fill")
				.foregroundStyle(.orange)
				.font(tinyFont)
			Text(message)
				.font(tinyFont)
				.foregroundStyle(.secondary)
				.lineLimit(2)
			Spacer()
			Button("Retry") { retry() }
				.buttonStyle(.borderless)
				.font(tinyFont.bold())
		}
		.padding(6)
		.background(.orange.opacity(0.08))
		.clipShape(RoundedRectangle(cornerRadius: 5))
	}

	private var unavailableView: some View {
		VStack(spacing: 8) {
			Image(systemName: "exclamationmark.triangle")
				.font(.title3)
				.foregroundStyle(.secondary)
			Text("Ollama is not running")
				.font(smallFont.bold())
			Text("Start Ollama to use AI features.")
				.font(tinyFont)
				.foregroundStyle(.secondary)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.padding(12)
	}

	// MARK: - Model Helpers

	private static let systemRAMGB: Double = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824

	private func modelFit(_ model: OllamaModel) -> ModelFit {
		let available = Self.systemRAMGB - 4.0
		let needed = model.estimatedRAMGB
		if needed <= available * 0.5 { return .ideal }
		if needed <= available { return .ok }
		return .heavy
	}

	private func loadModels() {
		Task {
			do {
				let client = ollamaClient()
				let models = try await client.listModels()
				availableModels = models.sorted { a, b in
					let fitA = modelFit(a).sortOrder
					let fitB = modelFit(b).sortOrder
					if fitA != fitB { return fitA < fitB }
					return a.size < b.size
				}
			} catch {
				isOllamaAvailable = false
			}
		}
	}

	// MARK: - Ollama Integration

	private func ollamaClient() -> OllamaClient {
		OllamaClient(baseURL: OllamaSettings.load().baseURL)
	}

	private func runSummary() {
		isSummarizing = true
		summary = ""
		summaryStatus = ""
		errorMessage = nil
		let lang = summaryLanguage
		Task {
			do {
				let client = ollamaClient()
				guard await client.checkAvailability() else {
					isOllamaAvailable = false
					isSummarizing = false
					return
				}
				isOllamaAvailable = true

				let summarizer = ArticleSummarizer(client: client, model: selectedModel)
				let langCode = SummaryLanguageCode(rawValue: lang.rawValue) ?? .english
				let stream = try await summarizer.summarize(
					articleText: articleExcerpt,
					title: articleTitle,
					language: langCode,
					onPhase: { @Sendable phase in
						Task { @MainActor in
							switch phase {
							case .summarizing:
								summaryStatus = ""
							case .refining(let chunk, let total):
								summaryStatus = "Refining \(chunk)/\(total)..."
							}
						}
					},
					onReplace: { @Sendable refined in
						Task { @MainActor in
							summary = Self.convertChineseVariant(refined, language: lang)
						}
					}
				)
				var raw = ""
				for try await token in stream {
					raw += token
					summary = raw
				}
				summary = Self.convertChineseVariant(raw, language: lang)
			} catch {
				errorMessage = error.localizedDescription
			}
			isSummarizing = false
			summaryStatus = ""
		}
	}

	private func runAnswer() {
		guard !question.isEmpty else { return }
		isAnswering = true
		errorMessage = nil
		let q = question
		question = ""

		let messageID = UUID().uuidString
		chatMessages.append(ChatMessage(id: messageID, question: q, answer: ""))

		Task {
			do {
				let client = ollamaClient()
				guard await client.checkAvailability() else {
					isOllamaAvailable = false
					isAnswering = false
					return
				}
				isOllamaAvailable = true

				let context = articleExcerpt.isEmpty ? articleTitle : articleExcerpt
				let qa = ArticleQA(client: client, model: selectedModel)
				let stream = try await qa.ask(question: q, articleText: context)
				for try await token in stream {
					let lastIdx = chatMessages.count - 1
					if lastIdx >= 0, chatMessages[lastIdx].id == messageID {
						chatMessages[lastIdx].answer += token
					}
				}
			} catch {
				errorMessage = error.localizedDescription
			}
			isAnswering = false
		}
	}

	/// Converts Chinese text to the correct variant (Traditional/Simplified)
	/// using Apple's ICU-based CFStringTransform. Small LLMs often output the
	/// wrong variant regardless of prompt instructions.
	private static func convertChineseVariant(_ text: String, language: SummaryLanguage) -> String {
		switch language {
		case .zhTW:
			let mutable = NSMutableString(string: text)
			CFStringTransform(mutable, nil, "Hans-Hant" as CFString, false)
			return mutable as String
		case .zhCN:
			let mutable = NSMutableString(string: text)
			CFStringTransform(mutable, nil, "Hant-Hans" as CFString, false)
			return mutable as String
		default:
			return text
		}
	}

	private func copyToClipboard(_ text: String) {
		#if os(macOS)
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(text, forType: .string)
		#else
		UIPasteboard.general.string = text
		#endif
	}

	private func copySummary(_ text: String) {
		copyToClipboard(text)
		didCopySummary = true
		DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
			didCopySummary = false
		}
	}

}

// MARK: - Supporting Types

struct ChatMessage: Identifiable {
	let id: String
	let question: String
	var answer: String
}

private enum SummaryLanguage: String, CaseIterable, Identifiable {
	case english, zhTW, zhCN, japanese, korean, spanish, french, german

	var id: String { rawValue }

	var label: String {
		switch self {
		case .english: "English"
		case .zhTW: "繁體中文"
		case .zhCN: "简体中文"
		case .japanese: "日本語"
		case .korean: "한국어"
		case .spanish: "Español"
		case .french: "Français"
		case .german: "Deutsch"
		}
	}

	var flag: String {
		switch self {
		case .english: "🇺🇸"
		case .zhTW: "🇹🇼"
		case .zhCN: "🇨🇳"
		case .japanese: "🇯🇵"
		case .korean: "🇰🇷"
		case .spanish: "🇪🇸"
		case .french: "🇫🇷"
		case .german: "🇩🇪"
		}
	}

	var shortLabel: String {
		switch self {
		case .english: "EN"
		case .zhTW: "繁中"
		case .zhCN: "简中"
		case .japanese: "JP"
		case .korean: "KR"
		case .spanish: "ES"
		case .french: "FR"
		case .german: "DE"
		}
	}
}

private enum ModelFit {
	case ideal, ok, heavy
	var label: String {
		switch self {
		case .ideal: "Ideal"
		case .ok: "OK"
		case .heavy: "Heavy"
		}
	}
	var color: Color {
		switch self {
		case .ideal: .green
		case .ok: .orange
		case .heavy: .red
		}
	}
	var sortOrder: Int {
		switch self {
		case .ideal: 0
		case .ok: 1
		case .heavy: 2
		}
	}
}

// MARK: - Shimmer

private struct ShimmerModifier: ViewModifier {
	@State private var phase: CGFloat = 0
	func body(content: Content) -> some View {
		content
			.overlay(
				LinearGradient(colors: [.clear, .white.opacity(0.3), .clear], startPoint: .leading, endPoint: .trailing)
					.offset(x: phase)
					.mask(content)
			)
			.onAppear {
				withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
					phase = 300
				}
			}
	}
}

private extension View {
	func shimmering() -> some View { modifier(ShimmerModifier()) }
}

// MARK: - Previews

#Preview("Collapsed") {
	HStack(spacing: 0) {
		Color.gray.opacity(0.05).frame(maxWidth: .infinity)
		OllamaArticlePanel(articleTitle: "AI Tools", articleExcerpt: "...", panelState: OllamaPanelState())
	}
	.frame(width: 700, height: 500)
}

#Preview("Expanded") {
	HStack(spacing: 0) {
		Color.gray.opacity(0.05).frame(maxWidth: .infinity)
		OllamaArticlePanel(
			articleTitle: "AI Coding Tools Are Changing How We Review Code",
			articleExcerpt: "The rapid proliferation of AI-powered coding assistants...",
			panelState: { let s = OllamaPanelState(); s.isExpanded = true; return s }()
		)
	}
	.frame(width: 700, height: 500)
}

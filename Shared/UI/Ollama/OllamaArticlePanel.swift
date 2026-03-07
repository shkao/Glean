//
//  OllamaArticlePanel.swift
//  Glean
//
//  Panel shown below or beside the article detail view.
//  Provides summarize, tag, and Q&A actions powered by Ollama.
//

import SwiftUI

struct OllamaArticlePanel: View {

	let articleTitle: String
	let articleExcerpt: String

	@State private var activeTab: PanelTab = .summary
	@State private var summary = ""
	@State private var tags: [String] = []
	@State private var question = ""
	@State private var answer = ""
	@State private var isLoading = false
	@State private var isOllamaAvailable = true

	var body: some View {
		VStack(spacing: 0) {
			// Tab bar
			tabBar

			Divider()

			// Content
			if !isOllamaAvailable {
				unavailableView
			} else {
				switch activeTab {
				case .summary:
					summaryView
				case .tags:
					tagsView
				case .ask:
					askView
				}
			}
		}
		.background(.background)
		.clipShape(RoundedRectangle(cornerRadius: 12))
		.overlay(
			RoundedRectangle(cornerRadius: 12)
				.stroke(.separator)
		)
	}

	// MARK: - Tab Bar

	private var tabBar: some View {
		HStack(spacing: 0) {
			tabButton(.summary, icon: "text.quote", label: "Summary")
			tabButton(.tags, icon: "tag", label: "Tags")
			tabButton(.ask, icon: "bubble.left.and.text.bubble.right", label: "Ask")

			Spacer()

			// Status indicator
			HStack(spacing: 4) {
				Circle()
					.fill(isOllamaAvailable ? .green : .red)
					.frame(width: 6, height: 6)
				Text(isOllamaAvailable ? "Ollama" : "Offline")
					.font(.caption2)
					.foregroundStyle(.secondary)
			}
			.padding(.trailing, 12)
		}
		.padding(.vertical, 4)
		.background(.bar)
	}

	private func tabButton(_ tab: PanelTab, icon: String, label: String) -> some View {
		Button {
			activeTab = tab
		} label: {
			Label(label, systemImage: icon)
				.font(.subheadline)
				.padding(.horizontal, 12)
				.padding(.vertical, 6)
				.background(activeTab == tab ? Color.accentColor.opacity(0.1) : .clear)
				.clipShape(RoundedRectangle(cornerRadius: 6))
		}
		.buttonStyle(.plain)
	}

	// MARK: - Summary View

	private var summaryView: some View {
		VStack(alignment: .leading, spacing: 12) {
			if summary.isEmpty && !isLoading {
				VStack(spacing: 12) {
					Text("Generate a 2-3 sentence summary of this article.")
						.font(.subheadline)
						.foregroundStyle(.secondary)

					Button {
						simulateSummary()
					} label: {
						Label("Summarize", systemImage: "sparkles")
					}
					.buttonStyle(.borderedProminent)
					.controlSize(.small)
				}
				.frame(maxWidth: .infinity)
				.padding()
			} else {
				ScrollView {
					VStack(alignment: .leading, spacing: 8) {
						if isLoading {
							HStack(spacing: 8) {
								ProgressView()
									.controlSize(.small)
								Text("Generating summary...")
									.font(.subheadline)
									.foregroundStyle(.secondary)
							}
						}

						if !summary.isEmpty {
							Text(summary)
								.font(.subheadline)
								.textSelection(.enabled)
						}
					}
					.padding()
				}

				if !summary.isEmpty {
					Divider()
					HStack {
						Button {
							summary = ""
						} label: {
							Label("Regenerate", systemImage: "arrow.clockwise")
						}
						.buttonStyle(.borderless)
						.font(.caption)

						Spacer()

						Button {
							copyToClipboard(summary)
						} label: {
							Label("Copy", systemImage: "doc.on.doc")
						}
						.buttonStyle(.borderless)
						.font(.caption)
					}
					.padding(.horizontal)
					.padding(.vertical, 8)
				}
			}
		}
	}

	// MARK: - Tags View

	private var tagsView: some View {
		VStack(alignment: .leading, spacing: 12) {
			if tags.isEmpty && !isLoading {
				VStack(spacing: 12) {
					Text("Generate topic tags for this article.")
						.font(.subheadline)
						.foregroundStyle(.secondary)

					Button {
						simulateTags()
					} label: {
						Label("Generate Tags", systemImage: "tag")
					}
					.buttonStyle(.borderedProminent)
					.controlSize(.small)
				}
				.frame(maxWidth: .infinity)
				.padding()
			} else {
				VStack(alignment: .leading, spacing: 12) {
					if isLoading {
						HStack(spacing: 8) {
							ProgressView()
								.controlSize(.small)
							Text("Generating tags...")
								.font(.subheadline)
								.foregroundStyle(.secondary)
						}
						.padding()
					}

					if !tags.isEmpty {
						FlowLayout(spacing: 8) {
							ForEach(tags, id: \.self) { tag in
								TagChip(tag: tag)
							}
						}
						.padding()
					}
				}
			}
		}
	}

	// MARK: - Ask View

	private var askView: some View {
		VStack(spacing: 0) {
			// Answer area
			ScrollView {
				if answer.isEmpty && !isLoading {
					VStack(spacing: 8) {
						Image(systemName: "bubble.left.and.text.bubble.right")
							.font(.title2)
							.foregroundStyle(.tertiary)
						Text("Ask a question about this article")
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}
					.frame(maxWidth: .infinity)
					.padding(.top, 32)
				} else {
					VStack(alignment: .leading, spacing: 8) {
						if isLoading {
							HStack(spacing: 8) {
								ProgressView()
									.controlSize(.small)
								Text("Thinking...")
									.font(.subheadline)
									.foregroundStyle(.secondary)
							}
						}
						if !answer.isEmpty {
							Text(answer)
								.font(.subheadline)
								.textSelection(.enabled)
						}
					}
					.padding()
				}
			}

			Divider()

			// Question input
			HStack(spacing: 8) {
				TextField("Ask about this article...", text: $question)
					.textFieldStyle(.roundedBorder)
					.onSubmit {
						simulateAnswer()
					}

				Button {
					simulateAnswer()
				} label: {
					Image(systemName: "arrow.up.circle.fill")
						.font(.title2)
				}
				.buttonStyle(.borderless)
				.disabled(question.isEmpty || isLoading)
			}
			.padding()
		}
	}

	// MARK: - Unavailable

	private var unavailableView: some View {
		VStack(spacing: 12) {
			Image(systemName: "exclamationmark.triangle")
				.font(.title2)
				.foregroundStyle(.secondary)
			Text("Ollama is not running")
				.font(.subheadline.bold())
			Text("Start Ollama on your Mac to use AI features.")
				.font(.caption)
				.foregroundStyle(.secondary)
		}
		.frame(maxWidth: .infinity)
		.padding()
	}

	// MARK: - Simulation

	private func simulateSummary() {
		isLoading = true
		summary = ""
		Task {
			let words = "This article discusses the rapid evolution of large language models and their growing integration into developer workflows. The author argues that while AI coding assistants can boost productivity for routine tasks, they introduce new categories of subtle bugs that require stronger code review practices. Key takeaway: teams should invest in review tooling proportional to their AI adoption rate.".split(separator: " ")
			for word in words {
				try? await Task.sleep(for: .milliseconds(40))
				summary += (summary.isEmpty ? "" : " ") + word
			}
			isLoading = false
		}
	}

	private func simulateTags() {
		isLoading = true
		Task {
			try? await Task.sleep(for: .seconds(1))
			tags = ["AI", "Developer Tools", "Code Review", "LLM", "Productivity"]
			isLoading = false
		}
	}

	private func simulateAnswer() {
		guard !question.isEmpty else { return }
		isLoading = true
		answer = ""
		let q = question
		question = ""
		Task {
			let response = "Based on the article, \(q.lowercased().hasSuffix("?") ? q.dropLast() : q[...]) is addressed in the second section. The author notes that current AI coding tools excel at boilerplate generation but struggle with architectural decisions. The recommendation is to use AI for implementation details while keeping humans in the loop for design choices."
			let words = response.split(separator: " ")
			for word in words {
				try? await Task.sleep(for: .milliseconds(35))
				answer += (answer.isEmpty ? "" : " ") + word
			}
			isLoading = false
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
}

// MARK: - Supporting Views

private enum PanelTab {
	case summary, tags, ask
}

private struct TagChip: View {
	let tag: String

	var body: some View {
		Text(tag)
			.font(.caption)
			.padding(.horizontal, 10)
			.padding(.vertical, 4)
			.background(.blue.opacity(0.1))
			.foregroundStyle(.blue)
			.clipShape(Capsule())
			.overlay(Capsule().stroke(.blue.opacity(0.2)))
	}
}

private struct FlowLayout: Layout {
	let spacing: CGFloat

	func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
		let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
		return layout(sizes: sizes, proposal: proposal).size
	}

	func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
		let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
		let positions = layout(sizes: sizes, proposal: proposal).positions

		for (index, subview) in subviews.enumerated() {
			subview.place(
				at: CGPoint(x: bounds.minX + positions[index].x, y: bounds.minY + positions[index].y),
				proposal: .unspecified
			)
		}
	}

	private func layout(sizes: [CGSize], proposal: ProposedViewSize) -> (size: CGSize, positions: [CGPoint]) {
		let maxWidth = proposal.width ?? .infinity
		var positions = [CGPoint]()
		var x: CGFloat = 0
		var y: CGFloat = 0
		var rowHeight: CGFloat = 0

		for size in sizes {
			if x + size.width > maxWidth && x > 0 {
				x = 0
				y += rowHeight + spacing
				rowHeight = 0
			}
			positions.append(CGPoint(x: x, y: y))
			rowHeight = max(rowHeight, size.height)
			x += size.width + spacing
		}

		return (CGSize(width: maxWidth, height: y + rowHeight), positions)
	}
}

// MARK: - Previews

#Preview("Ollama Panel - Summary") {
	OllamaArticlePanel(
		articleTitle: "AI Coding Tools Are Changing How We Review Code",
		articleExcerpt: "A deep dive into how LLM-powered development tools affect code quality..."
	)
	.frame(height: 300)
	.padding()
}

#Preview("Ollama Panel - Wide") {
	OllamaArticlePanel(
		articleTitle: "The Future of RSS in an AI World",
		articleExcerpt: "RSS feeds remain the best way to consume information..."
	)
	.frame(width: 600, height: 280)
	.padding()
}

#Preview("Article Detail + Ollama Panel") {
	VStack(spacing: 0) {
		// Simulated article content
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				Text("AI Coding Tools Are Changing How We Review Code")
					.font(.title.bold())
				Text("By Jane Smith, March 2026")
					.font(.subheadline)
					.foregroundStyle(.secondary)
				Text("The rapid proliferation of AI-powered coding assistants has fundamentally altered the landscape of software development. While these tools promise increased productivity and faster iteration cycles, they also introduce new challenges for code review processes that most teams are not yet equipped to handle.\n\nIn this article, we examine how leading engineering teams are adapting their review practices to account for AI-generated code, including new types of bugs, architectural drift, and the importance of maintaining human oversight.")
					.font(.body)
			}
			.padding()
		}
		.frame(height: 250)

		Divider()

		// Ollama panel below article
		OllamaArticlePanel(
			articleTitle: "AI Coding Tools Are Changing How We Review Code",
			articleExcerpt: "The rapid proliferation of AI-powered coding assistants..."
		)
		.frame(height: 280)
	}
	.frame(width: 600, height: 540)
}

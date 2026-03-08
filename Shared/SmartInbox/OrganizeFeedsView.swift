//
//  OrganizeFeedsView.swift
//  Glean
//
//  SwiftUI sheet for reviewing and accepting LLM-proposed feed organization.
//

import SwiftUI
import os
import Account

struct OrganizeFeedsView: View {

  private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.shkao.Glean", category: "OrganizeFeedsView")

  @Environment(\.dismiss) private var dismiss
  var onDismiss: (() -> Void)?

  @State private var selectedAccount: Account?
  @State private var includeAlreadyCategorized = false
  @State private var isClassifying = false
  @State private var proposal: SmartInboxController.Proposal?
  @State private var moveAccepted: [String: Bool] = [:]
  @State private var renameAccepted: [String: Bool] = [:]
  @State private var editedCategoryNames: [String: String] = [:]
  @State private var errorMessage: String?
  @State private var isExecuting = false
  @State private var isDone = false

  private let controller = SmartInboxController()

  private var eligibleAccounts: [Account] {
    AccountManager.shared.sortedActiveAccounts.filter { $0.type != .savedPages }
  }

  var body: some View {
    VStack(spacing: 0) {
      // Header with centered title
      ZStack {
        Text("Organize Feeds")
          .font(.headline)
        HStack {
          Button("Cancel") { close() }
            .buttonStyle(.borderless)
          Spacer()
        }
      }
      .padding()

      Divider()

      if isDone {
        doneView
      } else if let proposal {
        proposalView(proposal)
      } else {
        setupView
      }
    }
    #if os(macOS)
    .frame(width: 560, height: 520)
    #endif
    .onAppear {
      if selectedAccount == nil {
        selectedAccount = eligibleAccounts.first
      }
    }
  }

  // MARK: - Setup View

  private var setupView: some View {
    VStack(spacing: 24) {
      Spacer()

      if isClassifying {
        ProgressView("Classifying feeds...")
          .progressViewStyle(.circular)
      } else if let errorMessage {
        VStack(spacing: 12) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 40))
            .foregroundStyle(.orange)
          Text(errorMessage)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
      } else {
        Image(systemName: "folder.badge.gearshape")
          .font(.system(size: 48))
          .foregroundStyle(.secondary)

        VStack(spacing: 8) {
          Text("Auto-Organize Feeds")
            .font(.title2.bold())
          Text("Uses AI to classify your feeds into topic folders\nand clean up feed names.")
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
      }

      VStack(alignment: .leading, spacing: 12) {
        if eligibleAccounts.count > 1 {
          Picker("Account", selection: $selectedAccount) {
            ForEach(eligibleAccounts, id: \.accountID) { account in
              Text(account.nameForDisplay).tag(Optional(account))
            }
          }
          .pickerStyle(.menu)
          .frame(maxWidth: 300)
        }

        Toggle("Include feeds already in folders", isOn: $includeAlreadyCategorized)
      }
      .padding(.horizontal, 40)

      Spacer()

      HStack {
        Spacer()
        Button("Classify Feeds") {
          classifyFeeds()
        }
        .buttonStyle(.borderedProminent)
        .disabled(isClassifying || selectedAccount == nil)
      }
      .padding()
      .background(.bar)
    }
  }

  // MARK: - Proposal View

  private func proposalView(_ proposal: SmartInboxController.Proposal) -> some View {
    let renameLookup = Dictionary(
      uniqueKeysWithValues: proposal.renames.map { ($0.feed.feedID, $0) }
    )
    let movesByCategory = Dictionary(
      grouping: proposal.moves,
      by: \.destinationFolderName
    )
    let acceptedMoveCount = proposal.moves.filter { moveAccepted[$0.feed.feedID] ?? true }.count
    let acceptedRenameCount = proposal.renames.filter { renameAccepted[$0.feed.feedID] ?? true }.count

    return VStack(spacing: 0) {
      List {
        ForEach(proposal.categoryNames, id: \.self) { category in
          Section {
            ForEach(movesByCategory[category] ?? [], id: \.feed.feedID) { move in
              feedRow(move: move, rename: renameLookup[move.feed.feedID])
            }
          } header: {
            HStack(spacing: 6) {
              Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)
                .font(.caption)
              TextField("Folder", text: categoryNameBinding(for: category))
                .textFieldStyle(.plain)
                .font(.subheadline.bold())
            }
          }
        }
      }
      .listStyle(.plain)

      Divider()

      HStack {
        Text("\(acceptedMoveCount) moves, \(acceptedRenameCount) renames")
          .foregroundStyle(.secondary)
          .font(.subheadline)

        if isExecuting {
          ProgressView()
            .controlSize(.small)
        }

        Spacer()

        Button("Back") {
          self.proposal = nil
          errorMessage = nil
        }
        .disabled(isExecuting)

        Button("Organize") {
          executeProposal()
        }
        .buttonStyle(.borderedProminent)
        .disabled(isExecuting || (acceptedMoveCount + acceptedRenameCount) == 0)
      }
      .padding()
      .background(.bar)
    }
  }

  // MARK: - Feed Row

  @ViewBuilder
  private func feedRow(
    move: SmartInboxController.ProposedMove,
    rename: SmartInboxController.ProposedRename?
  ) -> some View {
    let feedID = move.feed.feedID
    let isRenameOn = rename != nil && (renameAccepted[feedID] ?? true)
    let host = URL(string: move.feed.url)?.host

    Toggle(isOn: moveBinding(for: move)) {
      VStack(alignment: .leading, spacing: 3) {
        if isRenameOn, let rename {
          HStack(spacing: 5) {
            Text(rename.suggestedName)
              .lineLimit(1)
            Image(systemName: "pencil.circle.fill")
              .font(.caption)
              .foregroundStyle(.blue.opacity(0.7))
          }
        } else {
          Text(move.feed.nameForDisplay)
            .lineLimit(1)
        }

        HStack(spacing: 0) {
          if let host {
            Text(host)
              .font(.caption)
              .foregroundStyle(.tertiary)
          }

          if isRenameOn {
            if host != nil {
              Text("  ·  ")
                .font(.caption)
                .foregroundStyle(.quaternary)
            }
            Text("was \(move.feed.nameForDisplay)")
              .font(.caption)
              .foregroundStyle(.tertiary)
              .italic()
              .lineLimit(1)
          }
        }
      }
    }
    .toggleStyle(.checkbox)
    .contextMenu {
      if rename != nil {
        let accepted = renameAccepted[feedID] ?? true
        Button(accepted ? "Keep Original Name" : "Use Suggested Name") {
          renameAccepted[feedID] = !accepted
        }
      }
    }
  }

  // MARK: - Done View

  private var doneView: some View {
    VStack(spacing: 24) {
      Spacer()

      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 56))
        .foregroundStyle(.green)

      VStack(spacing: 8) {
        Text("Feeds Organized")
          .font(.title2.bold())
        Text("Your feeds have been organized and renamed.")
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

  private func classifyFeeds() {
    guard let account = selectedAccount else { return }
    isClassifying = true
    errorMessage = nil

    Task {
      do {
        let result = try await controller.generateProposal(
          for: account,
          includeAlreadyCategorized: includeAlreadyCategorized
        )
        proposal = result
      } catch SmartInboxController.SmartInboxError.noAPIKey {
        errorMessage = "OpenRouter API key not configured. Set it in Settings."
      } catch SmartInboxController.SmartInboxError.noFeedsToClassify {
        errorMessage = "All feeds are already in folders."
      } catch {
        Self.logger.error("Classification failed: \(error)")
        errorMessage = "Classification failed: \(String(describing: error))"
      }
      isClassifying = false
    }
  }

  private func executeProposal() {
    guard var currentProposal = proposal else { return }
    isExecuting = true

    for i in currentProposal.moves.indices {
      let feedID = currentProposal.moves[i].feed.feedID
      currentProposal.moves[i].isAccepted = moveAccepted[feedID] ?? true

      let originalCategory = currentProposal.moves[i].destinationFolderName
      if let renamed = editedCategoryNames[originalCategory], !renamed.isEmpty {
        currentProposal.moves[i].destinationFolderName = renamed
      }
    }

    for i in currentProposal.renames.indices {
      let feedID = currentProposal.renames[i].feed.feedID
      currentProposal.renames[i].isAccepted = renameAccepted[feedID] ?? true
    }

    Task {
      do {
        try await controller.execute(proposal: currentProposal)
        isDone = true
      } catch {
        errorMessage = "Failed to organize feeds: \(error.localizedDescription)"
      }
      isExecuting = false
    }
  }

  // MARK: - Bindings

  private func moveBinding(for move: SmartInboxController.ProposedMove) -> Binding<Bool> {
    Binding(
      get: { moveAccepted[move.feed.feedID] ?? true },
      set: { moveAccepted[move.feed.feedID] = $0 }
    )
  }

  private func categoryNameBinding(for original: String) -> Binding<String> {
    Binding(
      get: { editedCategoryNames[original] ?? original },
      set: { editedCategoryNames[original] = $0 }
    )
  }
}

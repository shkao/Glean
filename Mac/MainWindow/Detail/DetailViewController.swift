//
//  DetailViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/26/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import WebKit
import SwiftUI
import RSCore
import Articles
import RSWeb

enum DetailState: Equatable {
	case noSelection
	case multipleSelection
	case loading
	case article(Article, CGFloat?)
	case extracted(Article, ExtractedArticle, CGFloat?)
}

final class DetailViewController: NSViewController, WKUIDelegate {

	@IBOutlet var containerView: DetailContainerView!
	@IBOutlet var statusBarView: DetailStatusBarView!

	private lazy var regularWebViewController = createWebViewController()
	private var searchWebViewController: DetailWebViewController?

	var windowState: DetailWindowState {
		currentWebViewController.windowState
	}

	private var currentWebViewController: DetailWebViewController! {
		didSet {
			let webview = currentWebViewController.view
			if containerView.contentView === webview {
				return
			}
			statusBarView.mouseoverLink = nil
			containerView.contentView = webview
		}
	}

	private var currentSourceMode: TimelineSourceMode = .regular {
		didSet {
			currentWebViewController = webViewController(for: currentSourceMode)
		}
	}

	private var detailStateForRegular: DetailState = .noSelection {
		didSet {
			webViewController(for: .regular).state = detailStateForRegular
		}
	}

	private var detailStateForSearch: DetailState = .noSelection {
		didSet {
			webViewController(for: .search).state = detailStateForSearch
		}
	}

	private var isArticleContentJavascriptEnabled = AppDefaults.shared.isArticleContentJavascriptEnabled

	override func viewDidLoad() {
		currentWebViewController = regularWebViewController
		NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
			Task { @MainActor in
				self?.userDefaultsDidChange()
			}
		}
	}

	// MARK: - API

	func setState(_ state: DetailState, mode: TimelineSourceMode) {
		switch mode {
		case .regular:
			detailStateForRegular = state
		case .search:
			detailStateForSearch = state
		}

		// Reset Ollama panel for the new article
		if case .article(let article, _) = state {
			updateOllamaPanel(for: article)
		} else if case .extracted(let article, _, _) = state {
			updateOllamaPanel(for: article)
		}
	}

	func showDetail(for mode: TimelineSourceMode) {
		currentSourceMode = mode
	}

	func stopMediaPlayback() {
		currentWebViewController.stopMediaPlayback()
	}

	func canScrollDown() async -> Bool {
		await currentWebViewController.canScrollDown()
	}

	func canScrollUp() async -> Bool {
		await currentWebViewController.canScrollUp()
	}

	override func scrollPageDown(_ sender: Any?) {
		currentWebViewController.scrollPageDown(sender)
	}

	override func scrollPageUp(_ sender: Any?) {
		currentWebViewController.scrollPageUp(sender)
	}

	// MARK: - Ollama Sidebar

	private var ollamaSidebarController: NSHostingController<OllamaArticlePanel>?
	private let ollamaPanelState = OllamaPanelState()

	func toggleOllamaPanel(for article: Article?) {
		if ollamaSidebarController == nil {
			embedOllamaSidebar(for: article)
		}
		withAnimation(.easeInOut(duration: 0.25)) {
			ollamaPanelState.isExpanded.toggle()
		}
	}

	private func embedOllamaSidebar(for article: Article?) {
		// Remove old sidebar
		containerView.setSidebarView(nil)
		ollamaSidebarController = nil

		let title = article?.title ?? ""
		let htmlContent = article?.contentHTML ?? article?.summary ?? ""
		let plainText = htmlContent.strippingHTML()
		let excerpt = String(plainText.prefix(4000))

		let panel = OllamaArticlePanel(articleTitle: title, articleExcerpt: excerpt, panelState: ollamaPanelState)
		let hosting = NSHostingController(rootView: panel)
		hosting.view.translatesAutoresizingMaskIntoConstraints = false
		hosting.sizingOptions = .intrinsicContentSize

		containerView.setSidebarView(hosting.view)
		ollamaSidebarController = hosting
	}

	/// Called when article selection changes to reset the sidebar.
	func updateOllamaPanel(for article: Article?) {
		let wasExpanded = ollamaPanelState.isExpanded
		embedOllamaSidebar(for: article)
		ollamaPanelState.isExpanded = wasExpanded
	}

	// MARK: - Navigation

	func focus() {
		guard let window = currentWebViewController.webView.window else {
			return
		}
		window.makeFirstResponderUnlessDescendantIsFirstResponder(currentWebViewController.webView)
	}
}

// MARK: - DetailWebViewControllerDelegate

extension DetailViewController: DetailWebViewControllerDelegate {

	func mouseDidEnter(_ detailWebViewController: DetailWebViewController, link: String) {
		guard !link.isEmpty, detailWebViewController === currentWebViewController else {
			return
		}
		statusBarView.mouseoverLink = link
	}

	func mouseDidExit(_ detailWebViewController: DetailWebViewController) {
		guard detailWebViewController === currentWebViewController else {
			return
		}
		statusBarView.mouseoverLink = nil
	}
}

// MARK: - Private

private extension DetailViewController {

	func createWebViewController() -> DetailWebViewController {
		let controller = DetailWebViewController()
		controller.delegate = self
		controller.state = .noSelection
		return controller
	}

	func webViewController(for mode: TimelineSourceMode) -> DetailWebViewController {
		switch mode {
		case .regular:
			return regularWebViewController
		case .search:
			if searchWebViewController == nil {
				searchWebViewController = createWebViewController()
			}
			return searchWebViewController!
		}
	}

	func userDefaultsDidChange() {
		if AppDefaults.shared.isArticleContentJavascriptEnabled != isArticleContentJavascriptEnabled {
			isArticleContentJavascriptEnabled = AppDefaults.shared.isArticleContentJavascriptEnabled
			createNewWebViewsAndRestoreState()
		}
	}

	func createNewWebViewsAndRestoreState() {

		regularWebViewController = createWebViewController()
		currentWebViewController = regularWebViewController
		regularWebViewController.state = detailStateForRegular

		searchWebViewController = nil

		if currentSourceMode == .search {
			searchWebViewController = createWebViewController()
			currentWebViewController = searchWebViewController
			searchWebViewController!.state = detailStateForSearch
		}
	}
}

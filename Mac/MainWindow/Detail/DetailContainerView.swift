//
//  DetailContainerView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/12/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit

final class DetailContainerView: NSView {

	@IBOutlet var detailStatusBarView: DetailStatusBarView!

	var contentViewConstraints: [NSLayoutConstraint]?

	var contentView: NSView? {
		didSet {
			if contentView == oldValue {
				return
			}

			if let currentConstraints = contentViewConstraints {
				NSLayoutConstraint.deactivate(currentConstraints)
			}
			contentViewConstraints = nil
			oldValue?.removeFromSuperviewWithoutNeedingDisplay()

			if let contentView {
				contentView.translatesAutoresizingMaskIntoConstraints = false
				addSubview(contentView, positioned: .below, relativeTo: detailStatusBarView)
				relayoutContent()
			}
		}
	}

	// MARK: - Sidebar

	private var sidebarView: NSView?
	private var sidebarConstraints: [NSLayoutConstraint]?

	/// Adds or replaces the sidebar view on the right edge.
	func setSidebarView(_ sidebar: NSView?) {
		// Remove old sidebar
		if let old = sidebarView {
			if let sc = sidebarConstraints {
				NSLayoutConstraint.deactivate(sc)
			}
			old.removeFromSuperview()
			sidebarConstraints = nil
			sidebarView = nil
		}

		guard let sidebar else {
			relayoutContent()
			return
		}

		sidebar.translatesAutoresizingMaskIntoConstraints = false
		addSubview(sidebar)
		sidebarView = sidebar

		let sc = [
			sidebar.topAnchor.constraint(equalTo: topAnchor),
			sidebar.trailingAnchor.constraint(equalTo: trailingAnchor),
			sidebar.bottomAnchor.constraint(equalTo: detailStatusBarView.topAnchor),
		]
		NSLayoutConstraint.activate(sc)
		sidebarConstraints = sc

		relayoutContent()
	}

	private func relayoutContent() {
		if let currentConstraints = contentViewConstraints {
			NSLayoutConstraint.deactivate(currentConstraints)
			contentViewConstraints = nil
		}

		guard let contentView else { return }

		var constraints = [
			contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
			contentView.topAnchor.constraint(equalTo: topAnchor),
			contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
		]

		if let sidebarView {
			constraints.append(contentView.trailingAnchor.constraint(equalTo: sidebarView.leadingAnchor))
		} else {
			constraints.append(contentView.trailingAnchor.constraint(equalTo: trailingAnchor))
		}

		NSLayoutConstraint.activate(constraints)
		contentViewConstraints = constraints
	}

	override func draw(_ dirtyRect: NSRect) {
		NSColor.controlBackgroundColor.set()
		let r = dirtyRect.intersection(bounds)
		r.fill()
	}
}

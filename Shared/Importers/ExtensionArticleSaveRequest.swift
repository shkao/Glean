//
//  ExtensionArticleSaveRequest.swift
//  Glean
//
//  Request to save a URL as an article in the SavedPages account.
//  Written by the share extension or Shortcuts intent, processed by the main app.
//

import Foundation

struct ExtensionArticleSaveRequest: Codable {

	enum Source: String, Codable {
		case shareExtension
		case chromeImport
		case screenshotImport
		case clipboardImport
	}

	let url: URL
	let title: String?
	let source: Source
}

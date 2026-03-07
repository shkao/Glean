//
//  ImportURLsIntent.swift
//  Glean
//
//  AppIntent for Shortcuts: accepts text containing URLs, extracts them,
//  and saves each as an article in the SavedPages account.
//

import AppIntents
import Foundation

struct ImportURLsIntent: AppIntent {

	static var title: LocalizedStringResource = "Import URLs to Glean"
	static var description: IntentDescription = "Import one or more URLs as saved articles in Glean."
	static var openAppWhenRun: Bool = false

	@Parameter(title: "Text containing URLs")
	var inputText: String

	func perform() async throws -> some IntentResult & ReturnsValue<Int> {
		let urls = URLExtractor.extractURLs(from: inputText)

		guard !urls.isEmpty else {
			throw ImportURLsIntentError.noURLsFound
		}

		for url in urls {
			let request = ExtensionArticleSaveRequest(
				url: url,
				title: nil,
				source: .chromeImport
			)
			ExtensionArticleSaveRequestFile.save(request)
		}

		return .result(value: urls.count)
	}

	static var parameterSummary: some ParameterSummary {
		Summary("Import URLs from \(\.$inputText)")
	}
}

enum ImportURLsIntentError: Error, CustomLocalizedStringResourceConvertible {
	case noURLsFound

	var localizedStringResource: LocalizedStringResource {
		switch self {
		case .noURLsFound:
			return "No URLs found in the provided text."
		}
	}
}

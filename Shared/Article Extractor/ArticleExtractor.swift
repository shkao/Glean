//
//  ArticleExtractor.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 9/18/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import Secrets

public enum ArticleExtractorState: Sendable {
    case ready
    case processing
    case failedToParse
    case complete
	case cancelled
}

@MainActor protocol ArticleExtractorDelegate {
	func articleExtractionDidFail(with: Error)
	func articleExtractionDidComplete(extractedArticle: ExtractedArticle)
}

@MainActor final class ArticleExtractor {
	let articleLink: String
	let delegate: ArticleExtractorDelegate
	var article: ExtractedArticle?

	var state = ArticleExtractorState.ready
	private var dataTask: URLSessionDataTask?

	public init(_ articleLink: String, delegate: ArticleExtractorDelegate) {
		self.articleLink = articleLink
		self.delegate = delegate
	}

	public func process() {
		state = .processing

		// Try Feedbin extract API first if keys are available
		let username = SecretKey.mercuryClientID
		if !username.isEmpty, let url = feedbinURL() {
			dataTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
				Task { @MainActor in
					guard let self, self.state != .cancelled else {
						return
					}
					if let data, error == nil,
					   let decoded = self.decodeFeedbinResponse(data),
					   decoded.content != nil {
						self.article = decoded
						self.state = .complete
						self.delegate.articleExtractionDidComplete(extractedArticle: decoded)
					} else {
						self.extractLocally()
					}
				}
			}
			dataTask?.resume()
		} else {
			extractLocally()
		}
	}

	public func cancel() {
		state = .cancelled
		dataTask?.cancel()
	}

	// MARK: - Private

	private func feedbinURL() -> URL? {
		let clientURL = "https://extract.feedbin.com/parser"
		let username = SecretKey.mercuryClientID
		let signature = articleLink.hmacUsingSHA1(key: SecretKey.mercuryClientSecret)
		guard let base64URL = articleLink.data(using: .utf8)?.base64EncodedString() else {
			return nil
		}
		return URL(string: "\(clientURL)/\(username)/\(signature)?base64_url=\(base64URL)")
	}

	private func decodeFeedbinResponse(_ data: Data) -> ExtractedArticle? {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		return try? decoder.decode(ExtractedArticle.self, from: data)
	}

	private func extractLocally() {
		guard state != .cancelled, let url = URL(string: articleLink) else {
			state = .failedToParse
			delegate.articleExtractionDidFail(with: URLError(.cannotDecodeContentData))
			return
		}

		Task {
			do {
				let extractor = WebContentExtractor()
				let extracted = try await extractor.extract(url: url)
				guard self.state != .cancelled else {
					return
				}
				if extracted.content != nil {
					self.article = extracted
					self.state = .complete
					self.delegate.articleExtractionDidComplete(extractedArticle: extracted)
				} else {
					self.state = .failedToParse
					self.delegate.articleExtractionDidFail(with: URLError(.cannotDecodeContentData))
				}
			} catch {
				guard self.state != .cancelled else {
					return
				}
				self.state = .failedToParse
				self.delegate.articleExtractionDidFail(with: error)
			}
		}
	}
}

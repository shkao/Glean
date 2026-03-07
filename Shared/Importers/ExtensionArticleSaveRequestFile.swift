//
//  ExtensionArticleSaveRequestFile.swift
//  Glean
//
//  Manages reading/writing article save requests via the app group container.
//  Mirrors the pattern in ExtensionFeedAddRequestFile but for saved articles.
//

import Foundation
import Synchronization
import os.log

final class ExtensionArticleSaveRequestFile: NSObject, NSFilePresenter, Sendable {

	static let shared = ExtensionArticleSaveRequestFile()

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ExtensionArticleSaveRequestFile")

	private static let filePath: String = {
		let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as! String
		let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
		return containerURL!.appendingPathComponent("extension_article_save_request.plist").path
	}()

	private let operationQueue = {
		let queue = OperationQueue()
		queue.maxConcurrentOperationCount = 1
		return queue
	}()

	var presentedItemURL: URL? {
		URL(fileURLWithPath: Self.filePath)
	}

	var presentedItemOperationQueue: OperationQueue {
		operationQueue
	}

	private let didStart = Mutex(false)

	func start() {
		var shouldBail = false
		didStart.withLock { didStart in
			if didStart {
				shouldBail = true
				return
			}
			didStart = true
		}

		if shouldBail { return }

		NSFileCoordinator.addFilePresenter(self)
		Task { @MainActor in
			process()
		}
	}

	func presentedItemDidChange() {
		Task { @MainActor in
			process()
		}
	}

	func resume() {
		NSFileCoordinator.addFilePresenter(self)
		Task { @MainActor in
			process()
		}
	}

	func suspend() {
		NSFileCoordinator.removeFilePresenter(self)
	}

	static func save(_ request: ExtensionArticleSaveRequest) {
		let decoder = PropertyListDecoder()
		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary

		let errorPointer: NSErrorPointer = nil
		let fileCoordinator = NSFileCoordinator()
		let fileURL = URL(fileURLWithPath: filePath)

		fileCoordinator.coordinate(writingItemAt: fileURL, options: [.forMerging], error: errorPointer, byAccessor: { url in
			do {
				var requests: [ExtensionArticleSaveRequest]
				if let fileData = try? Data(contentsOf: url),
				   let decoded = try? decoder.decode([ExtensionArticleSaveRequest].self, from: fileData) {
					requests = decoded
				} else {
					requests = []
				}

				requests.append(request)

				let data = try encoder.encode(requests)
				try data.write(to: url)
			} catch let error as NSError {
				logger.error("Save to disk failed: \(error.localizedDescription)")
			}
		})

		if let error = errorPointer?.pointee {
			logger.error("Save to disk coordination failed: \(error.localizedDescription)")
		}
	}
}

@MainActor private extension ExtensionArticleSaveRequestFile {

	func process() {
		let decoder = PropertyListDecoder()
		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary

		let errorPointer: NSErrorPointer = nil
		let fileCoordinator = NSFileCoordinator(filePresenter: self)
		let fileURL = URL(fileURLWithPath: Self.filePath)

		var requests: [ExtensionArticleSaveRequest]?

		fileCoordinator.coordinate(writingItemAt: fileURL, options: [.forMerging], error: errorPointer, byAccessor: { url in
			do {
				if let fileData = try? Data(contentsOf: url),
				   let decoded = try? decoder.decode([ExtensionArticleSaveRequest].self, from: fileData) {
					requests = decoded
				}

				let data = try encoder.encode([ExtensionArticleSaveRequest]())
				try data.write(to: url)
			} catch let error as NSError {
				Self.logger.error("Save to disk failed: \(error.localizedDescription)")
			}
		})

		if let error = errorPointer?.pointee {
			Self.logger.error("Save to disk coordination failed: \(error.localizedDescription)")
		}

		if let requests {
			for request in requests {
				processRequest(request)
			}
		}
	}

	func processRequest(_ request: ExtensionArticleSaveRequest) {
		// The main app will pick up these requests and use WebContentExtractor
		// to fetch article content, then save to the SavedPages account.
		NotificationCenter.default.post(
			name: .didReceiveArticleSaveRequest,
			object: self,
			userInfo: ["request": request]
		)
	}
}

public extension Notification.Name {
	static let didReceiveArticleSaveRequest = Notification.Name("didReceiveArticleSaveRequest")
}

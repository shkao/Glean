//
//  PhotosScreenshotScanner.swift
//  Glean
//
//  Fetches screenshots from the Photos library via PhotoKit.
//

import Foundation
import Photos
import CoreGraphics
import ImageIO

@MainActor final class PhotosScreenshotScanner {

	static func requestAuthorization() async -> PHAuthorizationStatus {
		await PHPhotoLibrary.requestAuthorization(for: .readWrite)
	}

	static var authorizationStatus: PHAuthorizationStatus {
		PHPhotoLibrary.authorizationStatus(for: .readWrite)
	}

	func fetchRecentScreenshots(limit: Int = 50, daysBack: Int = 30) -> [PHAsset] {
		let collections = PHAssetCollection.fetchAssetCollections(
			with: .smartAlbum,
			subtype: .smartAlbumScreenshots,
			options: nil
		)

		guard let album = collections.firstObject else {
			return []
		}

		let fetchOptions = PHFetchOptions()
		fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
		fetchOptions.fetchLimit = limit

		if daysBack > 0 {
			let cutoff = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
			fetchOptions.predicate = NSPredicate(format: "creationDate >= %@", cutoff as NSDate)
		}

		let assets = PHAsset.fetchAssets(in: album, options: fetchOptions)
		var result: [PHAsset] = []
		assets.enumerateObjects { asset, _, _ in
			result.append(asset)
		}
		return result
	}

	func requestCGImage(for asset: PHAsset) async -> CGImage? {
		await withCheckedContinuation { continuation in
			let options = PHImageRequestOptions()
			options.isSynchronous = false
			options.deliveryMode = .highQualityFormat
			options.isNetworkAccessAllowed = true

			PHImageManager.default().requestImageDataAndOrientation(
				for: asset,
				options: options
			) { data, _, _, _ in
				guard let data,
					  let source = CGImageSourceCreateWithData(data as CFData, nil),
					  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
					continuation.resume(returning: nil)
					return
				}
				continuation.resume(returning: cgImage)
			}
		}
	}

	func requestThumbnail(for asset: PHAsset, maxDimension: CGFloat = 200) async -> CGImage? {
		await withCheckedContinuation { continuation in
			let options = PHImageRequestOptions()
			options.isSynchronous = false
			options.deliveryMode = .fastFormat
			options.isNetworkAccessAllowed = false

			PHImageManager.default().requestImageDataAndOrientation(
				for: asset,
				options: options
			) { data, _, _, _ in
				guard let data,
					  let source = CGImageSourceCreateWithData(data as CFData, nil) else {
					continuation.resume(returning: nil)
					return
				}

				let thumbOptions: [CFString: Any] = [
					kCGImageSourceThumbnailMaxPixelSize: maxDimension,
					kCGImageSourceCreateThumbnailFromImageAlways: true,
					kCGImageSourceCreateThumbnailWithTransform: true
				]

				let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary)
				continuation.resume(returning: thumbnail)
			}
		}
	}

	func deleteAssets(_ assets: [PHAsset]) async throws {
		try await PHPhotoLibrary.shared().performChanges {
			PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
		}
	}
}

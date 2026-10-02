//
//  AssetImage.swift
//  Terris
//
//  Loads a photo thumbnail on demand from the Photos library by its PHAsset
//  local identifier, so Terris never has to persist full image blobs in
//  Core Data / CloudKit. A quick preview shows first and sharpens when the
//  full thumbnail arrives (from iCloud if the library keeps originals
//  there). When it can't be shown, the tile says why with its icon, and the
//  caller hears the reason (see PhotoProblem) to explain it in words.
//

import SwiftUI
import Photos

/// Why a photo can't be shown.
enum PhotoProblem: Equatable {
    /// Photos access is off.
    case noAccess
    /// Access is limited and this photo isn't among the ones shared.
    case notShared
    /// Not in this device's library: found on another device (photo
    /// references are per device), or deleted since.
    case missing
}

struct AssetImage: View {
    let assetIdentifier: String?
    var targetSize: CGSize = CGSize(width: 240, height: 240)
    /// Called when the photo can't be shown, with the reason.
    var onUnavailable: ((PhotoProblem) -> Void)? = nil

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var problem: PhotoProblem?

    var body: some View {
        ZStack {
            Theme.subtle
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                Image(systemName: icon)
                    .foregroundStyle(Theme.muted)
            }
        }
        .clipped()
        .task(id: assetIdentifier) { await load() }
    }

    private var icon: String {
        switch problem {
        case .noAccess, .notShared: "lock"
        case .missing: "photo.badge.exclamationmark"
        case nil: "photo"
        }
    }

    private func fail(_ reason: PhotoProblem) {
        problem = reason
        onUnavailable?(reason)
    }

    private func load() async {
        guard let id = assetIdentifier, !id.isEmpty else { return }
        var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        guard status == .authorized || status == .limited else { return fail(.noAccess) }
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else {
            return fail(status == .limited ? .notShared : .missing)
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic   // a fast preview, then the sharp one
        options.isNetworkAccessAllowed = true   // originals kept in iCloud
        options.resizeMode = .fast
        let size = CGSize(width: targetSize.width * displayScale, height: targetSize.height * displayScale)

        let stream = AsyncStream<UIImage> { continuation in
            let request = PHImageManager.default().requestImage(
                for: asset, targetSize: size, contentMode: .aspectFill, options: options
            ) { img, info in
                if let img { continuation.yield(img) }
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !degraded { continuation.finish() }
            }
            continuation.onTermination = { _ in PHImageManager.default().cancelImageRequest(request) }
        }
        for await img in stream {
            withAnimation(Motion.quick) { image = img }
        }
        // Leaving the screen cancels the load; that isn't a failure.
        if image == nil, !Task.isCancelled { fail(.missing) }
    }
}

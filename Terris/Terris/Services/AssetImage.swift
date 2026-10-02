//
//  AssetImage.swift
//  Terris
//
//  Loads a photo thumbnail on demand from the Photos library by its PHAsset
//  local identifier, so Terris never has to persist full image blobs in
//  Core Data / CloudKit. A quick preview shows first and sharpens when the
//  full thumbnail arrives (from iCloud if the library keeps originals
//  there). Without Photos access it shows a lock instead of a blank tile.
//

import SwiftUI
import Photos

struct AssetImage: View {
    let assetIdentifier: String?
    var targetSize: CGSize = CGSize(width: 240, height: 240)
    /// Called when the photo can't be shown (no access, or gone from the library).
    var onUnavailable: (() -> Void)? = nil

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var unavailable = false

    var body: some View {
        ZStack {
            Theme.subtle
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                Image(systemName: unavailable ? "lock" : "photo")
                    .foregroundStyle(Theme.muted)
            }
        }
        .clipped()
        .task(id: assetIdentifier) { await load() }
    }

    private func load() async {
        guard let id = assetIdentifier, !id.isEmpty else { return }
        var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        guard status == .authorized || status == .limited,
              let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
        else {
            unavailable = true
            onUnavailable?()
            return
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
        if image == nil {
            unavailable = true
            onUnavailable?()
        }
    }
}

//
//  AssetImage.swift
//  Terris
//
//  Loads a photo thumbnail on demand from the Photos library by its PHAsset
//  local identifier, so Terris never has to persist full image blobs in
//  Core Data / CloudKit. Falls back to any legacy inline data or a
//  placeholder when the asset is unavailable.
//

import SwiftUI
import Photos

struct AssetImage: View {
    let assetIdentifier: String?
    /// Legacy fallback for photos imported before reference-only storage.
    var legacyData: Data? = nil
    var targetSize: CGSize = CGSize(width: 200, height: 200)

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let legacyData, let img = UIImage(data: legacyData) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                ZStack {
                    Color(.tertiarySystemFill)
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
        }
        .task(id: assetIdentifier) { await load() }
    }

    private func load() async {
        guard image == nil, let id = assetIdentifier, !id.isEmpty else { return }
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
        else { return }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat   // single callback
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast

        let scale = UIScreen.main.scale
        let size = CGSize(width: targetSize.width * scale, height: targetSize.height * scale)

        let result: UIImage? = await withCheckedContinuation { continuation in
            var resumed = false
            PHImageManager.default().requestImage(
                for: asset, targetSize: size, contentMode: .aspectFill, options: options
            ) { img, _ in
                // Opportunistic delivery can call back more than once; resume once.
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: img)
            }
        }
        if let result { image = result }
    }
}

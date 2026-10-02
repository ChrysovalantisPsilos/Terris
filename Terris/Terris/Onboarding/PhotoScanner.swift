//
//  PhotoScanner.swift
//  Terris
//
//  Reads where the user's photos were taken, straight from the photo
//  library's metadata (PHAsset.location), and resolves each to a country
//  offline. Nothing leaves the device, and no image is loaded.
//
//  The system photo picker strips location data, so this reads the library
//  itself, which needs photo-library permission.
//

import Photos
import CoreLocation

nonisolated enum PhotoAccess: Equatable, Sendable {
    case granted, limited, denied, notDetermined

    static var current: PhotoAccess {
        map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    static func request() async -> PhotoAccess {
        map(await PHPhotoLibrary.requestAuthorization(for: .readWrite))
    }

    private static func map(_ status: PHAuthorizationStatus) -> PhotoAccess {
        switch status {
        case .authorized: .granted
        case .limited: .limited
        case .notDetermined: .notDetermined
        default: .denied
        }
    }
}

nonisolated enum PhotoScanner {
    /// Scans every image, newest first, and yields the running tally every
    /// `batch` photos. Cancelling the task stops the scan.
    static func scan(batch: Int = 250) -> AsyncStream<ScanTally> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                let options = PHFetchOptions()
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                options.includeHiddenAssets = false
                let assets = PHAsset.fetchAssets(with: .image, options: options)

                var tally = ScanTally()
                tally.total = assets.count
                continuation.yield(tally)

                let resolver = OfflineCountryResolver.shared
                var index = 0
                while index < assets.count, !Task.isCancelled {
                    let end = min(index + batch, assets.count)
                    for i in index..<end {
                        let asset = assets.object(at: i)
                        guard let location = asset.location else {
                            tally.add(nil)
                            continue
                        }
                        let c = location.coordinate
                        if let hit = resolver.resolve(latitude: c.latitude, longitude: c.longitude) {
                            tally.add(ScannedPhoto(id: asset.localIdentifier, iso: hit.iso, date: asset.creationDate))
                        } else {
                            tally.addUnplaced()
                        }
                    }
                    index = end
                    continuation.yield(tally)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

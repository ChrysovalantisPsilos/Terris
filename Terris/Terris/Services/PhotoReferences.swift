//
//  PhotoReferences.swift
//  Terris
//
//  How Terris refers to a photo so it opens on every device. A
//  PHAsset.localIdentifier only works on the device that found the photo;
//  iCloud Photos gives each photo a cloud identifier that maps back to the
//  local one on any device signed in to the same iCloud Photos library.
//  Terris stores "icloud:" + that identifier when iCloud Photos knows the
//  photo, and the local identifier otherwise (iCloud Photos off). Either way
//  it's a reference: the image never leaves Photos.
//

import Photos

nonisolated enum PhotoReferences {
    static let cloudPrefix = "icloud:"

    /// The cloud identifier inside a stored reference, if it is one.
    static func cloudValue(of reference: String) -> String? {
        reference.hasPrefix(cloudPrefix) ? String(reference.dropFirst(cloudPrefix.count)) : nil
    }

    static func reference(cloud value: String) -> String { cloudPrefix + value }

    /// The photo's identifier in this device's library, or nil when it
    /// isn't here (another iCloud Photos library, or deleted).
    static func localIdentifier(for reference: String) -> String? {
        guard let value = cloudValue(of: reference) else { return reference }
        let cloud = PHCloudIdentifier(stringValue: value)
        let mappings = PHPhotoLibrary.shared().localIdentifierMappings(for: [cloud])
        if case .success(let local)? = mappings[cloud] { return local }
        return nil
    }

    /// Cloud references for local identifiers that iCloud Photos knows,
    /// keyed by the local identifier; the others are left out.
    static func cloudReferences(forLocal identifiers: [String]) -> [String: String] {
        guard !identifiers.isEmpty else { return [:] }
        var out: [String: String] = [:]
        for (local, result) in PHPhotoLibrary.shared().cloudIdentifierMappings(forLocalIdentifiers: identifiers) {
            if case .success(let cloud) = result { out[local] = reference(cloud: cloud.stringValue) }
        }
        return out
    }

    /// Rewrites the references this device found earlier (local
    /// identifiers) as cloud references, so the photos open on the owner's
    /// other devices too. Runs at launch; does nothing without Photos access.
    @MainActor
    static func upgrade(in store: FootprintStore) async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return }
        let locals = store.localPhotoReferences()
        guard !locals.isEmpty else { return }
        let mapped = await Task.detached(priority: .utility) { cloudReferences(forLocal: locals) }.value
        store.replacePhotoReferences(mapped)
    }
}

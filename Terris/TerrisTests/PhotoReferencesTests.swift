//
//  PhotoReferencesTests.swift
//  TerrisTests
//
//  Photo references that work across devices: parsing, scans storing the
//  cloud form, and old local references being swapped without doubling.
//

import CoreData
import Foundation
import Testing
@testable import Terris

@MainActor
struct PhotoReferencesTests {
    // Kept for the test's life, so the in-memory store outlives its context.
    let persistence = PersistenceController(inMemory: true)

    func store() -> FootprintStore {
        FootprintStore(context: persistence.container.viewContext)
    }

    @Test func tellsCloudReferencesFromLocalOnes() {
        #expect(PhotoReferences.cloudValue(of: "icloud:ABC:001") == "ABC:001")
        #expect(PhotoReferences.cloudValue(of: "ABC/L0/001") == nil)
        #expect(PhotoReferences.reference(cloud: "ABC:001") == "icloud:ABC:001")
    }

    @Test func scansStoreTheCrossDeviceReferenceWhenThereIsOne() {
        let s = store()
        let scan = [ScannedCountry(iso: "JP", count: 2, first: nil, last: nil, samples: ["L1", "L2"])]
        s.applyScan(scan, references: ["L1": "icloud:C1"])
        #expect(Set(s.photoIdentifiers(for: "JP")) == ["icloud:C1", "L2"])
        // Only the photo iCloud Photos didn't know stays local.
        #expect(s.localPhotoReferences() == ["L2"])
    }

    @Test func swapsLocalReferencesWithoutDoublingPhotos() {
        let s = store()
        s.applyScan([ScannedCountry(iso: "JP", count: 2, first: nil, last: nil, samples: ["L1", "L2"])])
        s.applyScan([ScannedCountry(iso: "JP", count: 1, first: nil, last: nil, samples: ["L3"])],
                    references: ["L3": "icloud:C2"])
        // L1 becomes C1; L2 maps to C2, which is already stored, so it goes.
        s.replacePhotoReferences(["L1": "icloud:C1", "L2": "icloud:C2"])
        #expect(Set(s.photoIdentifiers(for: "JP")) == ["icloud:C1", "icloud:C2"])
        #expect(s.localPhotoReferences().isEmpty)
    }

    @Test func theCoverComesFirst() {
        #expect(FootprintStore.coverFirst(["a", "b", "c"], cover: "c") == ["c", "a", "b"])
        #expect(FootprintStore.coverFirst(["a", "b"], cover: "gone") == ["a", "b"])
        #expect(FootprintStore.coverFirst(["a", "b"], cover: nil) == ["a", "b"])
    }

    @Test func choosingACoverAndRemovingPhotos() {
        let s = store()
        s.applyScan([ScannedCountry(iso: "SA", count: 3, first: nil, last: nil, samples: ["icloud:A", "icloud:B", "icloud:C"])])
        s.setCoverPhoto("icloud:C", for: "SA")
        #expect(s.photoIdentifiers(for: "SA").first == "icloud:C")
        #expect(s.record(for: "SA")?.coverPhoto == "icloud:C")
        // Removing the cover clears it; the others stay.
        s.removePhotos(["icloud:C", "icloud:A"], from: "SA")
        #expect(s.photoIdentifiers(for: "SA") == ["icloud:B"])
        #expect(s.record(for: "SA")?.coverPhoto == nil)
    }
}

//
//  ScanFigures.swift
//  Terris
//
//  Folds photo locations into countries: how many photos, first and last
//  date, and a few of the newest photos to show on the country page.
//  Pure and tested (ScanFiguresTests).
//

import Foundation

nonisolated struct ScannedPhoto: Equatable, Sendable {
    var id: String
    var iso: String
    var date: Date?
}

nonisolated struct ScannedCountry: Equatable, Sendable, Identifiable {
    var iso: String
    var count: Int
    var first: Date?
    var last: Date?
    /// The newest photos' identifiers, newest first.
    var samples: [String]
    var id: String { iso }
}

nonisolated struct ScanTally: Equatable, Sendable {
    static let sampleLimit = 8

    private(set) var countries: [String: ScannedCountry] = [:]
    /// Countries in the order they were first found, for the "found" chips.
    private(set) var foundOrder: [String] = []
    private(set) var processed = 0
    private(set) var withLocation = 0
    var total = 0

    var fraction: Double { total > 0 ? min(Double(processed) / Double(total), 1) : 0 }

    mutating func add(_ photo: ScannedPhoto?) {
        processed += 1
        guard let photo else { return }
        withLocation += 1
        var c = countries[photo.iso] ?? ScannedCountry(iso: photo.iso, count: 0, first: nil, last: nil, samples: [])
        if c.count == 0 { foundOrder.append(photo.iso) }
        c.count += 1
        if let d = photo.date {
            c.first = min(c.first ?? d, d)
            c.last = max(c.last ?? d, d)
        }
        // Photos arrive newest first, so the first few are the newest.
        if c.samples.count < Self.sampleLimit { c.samples.append(photo.id) }
        countries[photo.iso] = c
    }

    /// Located but not in any country (at sea, or a place the map doesn't cover).
    mutating func addUnplaced() {
        processed += 1
        withLocation += 1
    }

    /// Per-country results, most photos first.
    var results: [ScannedCountry] {
        countries.values.sorted { $0.count != $1.count ? $0.count > $1.count : $0.iso < $1.iso }
    }
}

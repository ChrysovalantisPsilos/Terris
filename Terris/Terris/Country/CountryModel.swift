//
//  CountryModel.swift
//  Terris
//

import Foundation
import Observation

/// What the country page shows, from plain values (tested in CountryFiguresTests).
struct CountryFigures: Equatable, Sendable {
    var iso: String
    var name: String
    var continent: String
    var status: TravelStatus
    var firstVisit: Date?
    var lastVisit: Date?
    var notes: String
    var cities: [String]
    var photoCount: Int
    var facts: [String]
    /// The photo the owner chose as the cover, if any.
    var cover: String?

    /// Dates only make sense once you've been.
    var showsDates: Bool { status == .visited || status == .livedIn }

    static func compute(entry: CountryEntry, record: CountryRecord?, facts: [String]) -> CountryFigures {
        CountryFigures(
            iso: entry.isoCode,
            name: entry.name,
            continent: entry.continent,
            status: record?.status ?? .none,
            firstVisit: record?.firstVisit,
            lastVisit: record?.lastVisit,
            notes: record?.notes ?? "",
            cities: record?.cities ?? [],
            photoCount: record?.photoCount ?? 0,
            facts: facts,
            cover: record?.coverPhoto)
    }

    /// Tapping the selected status again clears it.
    static func nextStatus(current: TravelStatus, tapped: TravelStatus) -> TravelStatus {
        current == tapped ? .none : tapped
    }
}

@MainActor
@Observable
final class CountryModel {
    let iso: String
    private(set) var figures: CountryFigures?
    private(set) var photoIDs: [String] = []
    private let store: FootprintStore

    init(iso: String, store: FootprintStore) {
        self.iso = iso
        self.store = store
    }

    var error: String? { store.lastError }

    func load() {
        guard let entry = store.entry(for: iso) else { figures = nil; return }
        figures = CountryFigures.compute(entry: entry, record: store.record(for: iso),
                                         facts: CountryFacts.facts(for: iso))
        photoIDs = store.photoIdentifiers(for: iso, limit: 12)
    }

    func tap(_ status: TravelStatus) {
        let current = figures?.status ?? .none
        store.setStatus(CountryFigures.nextStatus(current: current, tapped: status), for: iso)
        load()
    }

    func setFirstVisit(_ date: Date?) { store.setFirstVisit(date, for: iso); load() }
    func setLastVisit(_ date: Date?) { store.setLastVisit(date, for: iso); load() }
    func setNotes(_ notes: String) {
        guard notes != (figures?.notes ?? "") else { return }
        store.setNotes(notes, for: iso)
        load()
    }
    func addCity(_ name: String) { store.addCity(name, to: iso); load() }
    func setCover(_ reference: String?) { store.setCoverPhoto(reference, for: iso); load() }
    func removePhotos(_ references: [String]) { store.removePhotos(references, from: iso); load() }
    func removeCity(_ name: String) { store.removeCity(name, from: iso); load() }
}

//
//  MapFigures.swift
//  Terris
//
//  Every figure the Map tab shows, computed in one place from plain values.
//  "Been to" = visited + lived; the globe shading, the headline count and the
//  continent breakdown all come from here so they can never disagree.
//

import Foundation

/// A country the user has marked, as the store reads it.
struct CountryRecord: Equatable, Sendable {
    var iso: String
    var status: TravelStatus
    var statusChangedAt: Date?
    var firstVisit: Date?
    var lastVisit: Date?
    var notes: String?
    var cities: [String]
    var photoCount: Int
}

/// One row in a list of countries.
struct CountryRow: Equatable, Sendable, Identifiable {
    var iso: String
    var name: String
    var continent: String
    var status: TravelStatus
    var date: Date?
    var cityCount: Int
    var id: String { iso }
    var flag: String { Flag.emoji(for: iso) }
}

struct ContinentFigure: Equatable, Sendable, Identifiable {
    var name: String
    var beenTo: Int
    var total: Int
    var id: String { name }
    var fraction: Double { total > 0 ? Double(beenTo) / Double(total) : 0 }
}

struct AtlasSection: Equatable, Sendable, Identifiable {
    var continent: String
    var beenTo: Int
    var total: Int
    var rows: [CountryRow]
    var id: String { continent }
}

struct MapFigures: Equatable, Sendable {
    var beenTo: Int
    var visited: Int
    var lived: Int
    var wantTo: Int
    var total: Int
    var cityCount: Int
    var statusByISO: [String: TravelStatus]
    var continents: [ContinentFigure]
    var recent: [CountryRow]
    var wishlist: [CountryRow]
    var atlas: [AtlasSection]
    var cities: [CityRow]

    /// Share of the world, 0…1.
    var fraction: Double { total > 0 ? Double(beenTo) / Double(total) : 0 }
    /// Whole percent, rounded, for the headline.
    var percent: Int { Int((fraction * 100).rounded()) }

    struct CityRow: Equatable, Sendable, Identifiable {
        var name: String
        var iso: String
        var id: String { iso + "|" + name }
        var flag: String { Flag.emoji(for: iso) }
    }

    /// Continents in the order the app lists them (Antarctica has no countries).
    static let continentOrder = ["Europe", "Asia", "North America", "Africa", "South America", "Oceania"]

    static func compute(records: [CountryRecord], catalog: [CountryEntry], recentLimit: Int = 6) -> MapFigures {
        let entryByISO = Dictionary(catalog.map { ($0.isoCode, $0) }, uniquingKeysWith: { a, _ in a })
        // Only countries in the catalog count, so the total and the count share a list.
        let known = records.filter { entryByISO[$0.iso] != nil }
        func isBeenTo(_ s: TravelStatus) -> Bool { s == .visited || s == .livedIn }

        func row(_ r: CountryRecord) -> CountryRow {
            let e = entryByISO[r.iso]!
            return CountryRow(iso: r.iso, name: e.name, continent: e.continent,
                              status: r.status, date: r.statusChangedAt, cityCount: r.cities.count)
        }

        let marked = known.filter { $0.status != .none }
        let beenTo = marked.filter { isBeenTo($0.status) }

        let continents = continentOrder.map { name in
            ContinentFigure(name: name,
                            beenTo: beenTo.filter { entryByISO[$0.iso]?.continent == name }.count,
                            total: catalog.filter { $0.continent == name }.count)
        }

        let recent = marked
            .sorted { ($0.statusChangedAt ?? .distantPast) > ($1.statusChangedAt ?? .distantPast) }
            .prefix(recentLimit)
            .map(row)

        let wishlist = marked.filter { $0.status == .wantToVisit }.map(row)
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }

        let atlas = zip(continentOrder, continents).compactMap { pair -> AtlasSection? in
            let (name, figure) = pair
            let rows = beenTo.filter { entryByISO[$0.iso]?.continent == name }.map(row)
                .sorted { lhs, rhs in
                    // Lived first, then by name.
                    if lhs.status != rhs.status { return lhs.status == .livedIn }
                    return lhs.name.localizedCompare(rhs.name) == .orderedAscending
                }
            return rows.isEmpty ? nil : AtlasSection(continent: name, beenTo: figure.beenTo,
                                                     total: figure.total, rows: rows)
        }

        let cities = known.flatMap { r in r.cities.map { CityRow(name: $0, iso: r.iso) } }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }

        return MapFigures(
            beenTo: beenTo.count,
            visited: marked.filter { $0.status == .visited }.count,
            lived: marked.filter { $0.status == .livedIn }.count,
            wantTo: wishlist.count,
            total: catalog.count,
            cityCount: cities.count,
            statusByISO: Dictionary(marked.map { ($0.iso, $0.status) }, uniquingKeysWith: { a, _ in a }),
            continents: continents,
            recent: recent,
            wishlist: wishlist,
            atlas: atlas,
            cities: cities)
    }
}

enum Flag {
    /// "JP" → 🇯🇵. Unknown codes give an empty string.
    static func emoji(for iso: String) -> String {
        let upper = iso.uppercased()
        guard upper.count == 2, upper.unicodeScalars.allSatisfy({ $0.value >= 65 && $0.value <= 90 }) else { return "" }
        return String(String.UnicodeScalarView(upper.unicodeScalars.compactMap {
            Unicode.Scalar(127_397 + $0.value)
        }))
    }
}

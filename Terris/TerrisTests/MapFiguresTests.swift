//
//  MapFiguresTests.swift
//  TerrisTests
//

import Foundation
import Testing
@testable import Terris

@MainActor
struct MapFiguresTests {
    let catalog = [
        CountryEntry(name: "Greece", isoCode: "GR", continent: "Europe"),
        CountryEntry(name: "Belgium", isoCode: "BE", continent: "Europe"),
        CountryEntry(name: "France", isoCode: "FR", continent: "Europe"),
        CountryEntry(name: "Japan", isoCode: "JP", continent: "Asia"),
        CountryEntry(name: "Brazil", isoCode: "BR", continent: "South America"),
        CountryEntry(name: "Kenya", isoCode: "KE", continent: "Africa"),
    ]

    func record(_ iso: String, _ status: TravelStatus, day: Int = 1, cities: [String] = []) -> CountryRecord {
        CountryRecord(iso: iso, status: status,
                      statusChangedAt: Date(timeIntervalSince1970: Double(day) * 86_400),
                      firstVisit: nil, lastVisit: nil, notes: nil, cities: cities, photoCount: 0)
    }

    @Test func beenToIsVisitedPlusLived() {
        let f = MapFigures.compute(records: [
            record("GR", .livedIn), record("FR", .visited), record("JP", .visited),
            record("BR", .wantToVisit), record("BE", .none),
        ], catalog: catalog)
        #expect(f.beenTo == 3)
        #expect(f.visited == 2)
        #expect(f.lived == 1)
        #expect(f.wantTo == 1)
        #expect(f.total == 6)
        #expect(f.percent == 50)
    }

    @Test func shadingCountAndContinentsAgree() {
        let f = MapFigures.compute(records: [
            record("GR", .livedIn), record("FR", .visited), record("JP", .visited), record("KE", .wantToVisit),
        ], catalog: catalog)
        let shadedBeenTo = f.statusByISO.values.filter { $0 == .visited || $0 == .livedIn }.count
        #expect(shadedBeenTo == f.beenTo)
        #expect(f.continents.map(\.beenTo).reduce(0, +) == f.beenTo)
        #expect(f.atlas.map(\.rows.count).reduce(0, +) == f.beenTo)
    }

    @Test func continentTotalsComeFromTheCatalog() {
        let f = MapFigures.compute(records: [], catalog: catalog)
        let europe = f.continents.first { $0.name == "Europe" }!
        #expect(europe.total == 3)
        #expect(f.continents.map(\.name) == MapFigures.continentOrder)
    }

    @Test func countriesOutsideTheCatalogDontCount() {
        let f = MapFigures.compute(records: [record("ZZ", .visited), record("JP", .visited)], catalog: catalog)
        #expect(f.beenTo == 1)
        #expect(f.statusByISO["ZZ"] == nil)
    }

    @Test func recentIsNewestFirstAndLimited() {
        let f = MapFigures.compute(records: [
            record("GR", .livedIn, day: 1), record("FR", .visited, day: 3),
            record("JP", .visited, day: 2), record("BR", .wantToVisit, day: 4),
        ], catalog: catalog, recentLimit: 3)
        #expect(f.recent.map(\.iso) == ["BR", "FR", "JP"])
    }

    @Test func atlasListsLivedFirstThenByName() {
        let f = MapFigures.compute(records: [
            record("FR", .visited), record("BE", .visited), record("GR", .livedIn),
        ], catalog: catalog)
        #expect(f.atlas.first?.rows.map(\.iso) == ["GR", "BE", "FR"])
        #expect(f.atlas.first?.continent == "Europe")
    }

    @Test func citiesAreCountedAndListed() {
        let f = MapFigures.compute(records: [
            record("JP", .visited, cities: ["Tokyo", "Kyoto"]), record("FR", .visited, cities: ["Paris"]),
        ], catalog: catalog)
        #expect(f.cityCount == 3)
        #expect(f.cities.map(\.name) == ["Kyoto", "Paris", "Tokyo"])
    }

    @Test func emptyWorld() {
        let f = MapFigures.compute(records: [], catalog: catalog)
        #expect(f.beenTo == 0)
        #expect(f.percent == 0)
        #expect(f.recent.isEmpty && f.wishlist.isEmpty && f.atlas.isEmpty)
    }

    @Test func flags() {
        #expect(Flag.emoji(for: "JP") == "🇯🇵")
        #expect(Flag.emoji(for: "gr") == "🇬🇷")
        #expect(Flag.emoji(for: "-99") == "")
    }

    @Test func theRealCatalogHasNoDuplicates() {
        let codes = CountryData.all.map(\.isoCode)
        #expect(Set(codes).count == codes.count)
    }
}

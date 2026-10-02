//
//  CountryTests.swift
//  TerrisTests
//

import Foundation
import Testing
@testable import Terris

@MainActor
struct CountryTests {
    let japan = CountryEntry(name: "Japan", isoCode: "JP", continent: "Asia")

    @Test func unmarkedCountryHasDefaults() {
        let f = CountryFigures.compute(entry: japan, record: nil, facts: ["A fact."])
        #expect(f.status == .none)
        #expect(!f.showsDates)
        #expect(f.facts == ["A fact."])
        #expect(f.notes == "")
    }

    @Test func datesShowOnlyOnceYouHaveBeen() {
        for (status, shows) in [(TravelStatus.visited, true), (.livedIn, true), (.wantToVisit, false), (.none, false)] {
            let record = CountryRecord(iso: "JP", status: status, statusChangedAt: nil, firstVisit: nil,
                                       lastVisit: nil, notes: nil, cities: [], photoCount: 0)
            #expect(CountryFigures.compute(entry: japan, record: record, facts: []).showsDates == shows)
        }
    }

    @Test func tappingTheSelectedStatusClearsIt() {
        #expect(CountryFigures.nextStatus(current: .visited, tapped: .visited) == .none)
        #expect(CountryFigures.nextStatus(current: .visited, tapped: .livedIn) == .livedIn)
        #expect(CountryFigures.nextStatus(current: .none, tapped: .wantToVisit) == .wantToVisit)
    }

    @Test func searchMatchesPrefixFirstIgnoringCaseAndAccents() {
        let entries = [
            CountryEntry(name: "Côte d'Ivoire", isoCode: "CI", continent: "Africa"),
            CountryEntry(name: "Malta", isoCode: "MT", continent: "Europe"),
            CountryEntry(name: "Somalia", isoCode: "SO", continent: "Africa"),
            CountryEntry(name: "Mali", isoCode: "ML", continent: "Africa"),
        ]
        #expect(CountrySearch.filter(entries, query: "mal").map(\.isoCode) == ["ML", "MT", "SO"])
        #expect(CountrySearch.filter(entries, query: "cote").map(\.isoCode) == ["CI"])
        #expect(CountrySearch.filter(entries, query: "mt").map(\.isoCode) == ["MT"])
        #expect(CountrySearch.filter(entries, query: "").count == 4)
    }

    @Test func cityChipsWrapOnlyWhenTheyDoNotFit() {
        let chip = CGSize(width: 80, height: 44)
        // Four 80pt chips with 8pt gaps need exactly 344pt: one row at 344.
        let exact = FlowLayout.rows(Array(repeating: chip, count: 4), width: 344, spacing: 8)
        #expect(exact.count == 1)
        #expect(exact[0].width == 344)
        // One point narrower: the last chip wraps.
        let tight = FlowLayout.rows(Array(repeating: chip, count: 4), width: 343, spacing: 8)
        #expect(tight.map(\.indices) == [[0, 1, 2], [3]])
        #expect(FlowLayout.rows([], width: 300, spacing: 8).isEmpty)
    }
}

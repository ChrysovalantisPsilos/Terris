//
//  FlightDraftTests.swift
//  TerrisTests
//

import Foundation
import Testing
@testable import Terris

@MainActor
struct FlightDraftTests {
    let bru = AirportRecord(iata: "BRU", icao: "EBBR", name: "Brussels Airport", city: "Brussels",
                            countryISO: "BE", lat: 50.9014, lon: 4.4844)
    let ath = AirportRecord(iata: "ATH", icao: "LGAV", name: "Athens International", city: "Athens",
                            countryISO: "GR", lat: 37.9364, lon: 23.9445)
    let now = Date(timeIntervalSince1970: 1_780_000_000)

    @Test func needsBothAirports() {
        var d = FlightDraft.new(now: now)
        #expect(d.problem == .missingRoute)
        d.from = bru
        #expect(!d.canSave)
        d.to = ath
        #expect(d.canSave)
    }

    @Test func sameAirportIsRefused() {
        var d = FlightDraft.new(now: now)
        d.from = bru; d.to = bru
        #expect(d.problem == .sameAirport)
        #expect(d.distanceKm == nil)
    }

    @Test func arrivalMustBeAfterDeparture() {
        var d = FlightDraft.new(now: now)
        d.from = bru; d.to = ath
        d.arrival = now.addingTimeInterval(-60)
        #expect(d.problem == .arrivesBeforeDeparture)
        d.arrival = now.addingTimeInterval(3 * 3600 + 15 * 60)
        #expect(d.canSave)
        #expect(d.minutes == 195)
    }

    @Test func distanceBrusselsToAthens() {
        var d = FlightDraft.new(now: now)
        d.from = bru; d.to = ath
        let km = d.distanceKm!
        #expect(km > 2050 && km < 2130)
    }

    @Test func swapAirports() {
        var d = FlightDraft.new(now: now)
        d.from = bru; d.to = ath
        d.swapAirports()
        #expect(d.from?.iata == "ATH" && d.to?.iata == "BRU")
    }

    @Test func statusComesFromTheDate() {
        var d = FlightDraft.new(now: now)
        #expect(d.status(now: now.addingTimeInterval(60)) == "completed")
        d.departure = now.addingTimeInterval(86_400)
        #expect(d.status(now: now) == "upcoming")
    }

    @Test func seatClassRoundTrips() {
        for c in SeatClass.allCases { #expect(SeatClass(rawValue: c.rawValue) == c) }
        #expect(SeatClass(rawValue: "Premium Economy") == .premiumEconomy)
    }

    @Test func airportSearchRanksCodesFirst() {
        let lis = AirportRecord(iata: "LIS", icao: "LPPT", name: "Humberto Delgado", city: "Lisbon",
                                countryISO: "PT", lat: 38.77, lon: -9.13)
        let all = [lis, ath, bru]
        #expect(AirportSearch.filter(all, query: "ath").map(\.iata) == ["ATH"])
        #expect(AirportSearch.filter(all, query: "br").first?.iata == "BRU")
        #expect(AirportSearch.filter(all, query: "lisb").map(\.iata) == ["LIS"])
        #expect(AirportSearch.filter(all, query: "gr").map(\.iata) == ["ATH"])
        #expect(AirportSearch.filter(all, query: "  ").isEmpty)
    }

    @Test func realAirportListHasUniqueCodes() {
        let codes = kAirportDatabase.map(\.iata)
        #expect(Set(codes).count == codes.count)
    }
}

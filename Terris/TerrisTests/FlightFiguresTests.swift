//
//  FlightFiguresTests.swift
//  TerrisTests
//

import Foundation
import Testing
@testable import Terris

@MainActor
struct FlightFiguresTests {
    var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    func flight(_ from: String, _ to: String, year: Int?, km: Double,
                fromCountry: String? = nil, toCountry: String? = nil) -> FlightRecord {
        let date = year.map { utc.date(from: DateComponents(year: $0, month: 6, day: 14))! }
        return FlightRecord(id: UUID(), date: date, from: from, to: to,
                            fromPoint: GeoPoint(lon: 4.48, lat: 50.9), toPoint: GeoPoint(lon: 23.9, lat: 37.9),
                            fromCountry: fromCountry, toCountry: toCountry,
                            airline: nil, number: nil, km: km)
    }

    @Test func totals() {
        let f = FlightFigures.compute([
            flight("BRU", "ATH", year: 2026, km: 2090, fromCountry: "BE", toCountry: "GR"),
            flight("ATH", "BRU", year: 2026, km: 2090, fromCountry: "GR", toCountry: "BE"),
            flight("ATH", "DXB", year: 2025, km: 2950, fromCountry: "GR", toCountry: "AE"),
        ], calendar: utc)
        #expect(f.count == 3)
        #expect(f.km == 7130)
        #expect(f.airports == 3)
        #expect(f.countries == 3)
    }

    @Test func sectionsAreNewestYearFirstWithUndatedLast() {
        let f = FlightFigures.compute([
            flight("A", "B", year: 2024, km: 1), flight("C", "D", year: nil, km: 1),
            flight("E", "F", year: 2026, km: 1),
        ], calendar: utc)
        #expect(f.sections.map(\.year) == [2026, 2024, nil])
    }

    @Test func oneArcPerAirportPair() {
        let f = FlightFigures.compute([
            flight("BRU", "ATH", year: 2026, km: 1), flight("ATH", "BRU", year: 2026, km: 1),
        ], calendar: utc)
        #expect(f.routes.count == 1)
    }

    @Test func timesAroundTheEarth() {
        let f = FlightFigures.compute([flight("A", "B", year: 2026, km: 128_400)], calendar: utc)
        #expect(f.timesAroundEarth == 3.2)
    }

    @Test func greatCircleStartsAndEndsAtTheAirports() {
        let a = GeoPoint(lon: 4.48, lat: 50.9), b = GeoPoint(lon: 140.4, lat: 35.8)
        let path = Projection.greatCircle(from: a, to: b, steps: 32)
        #expect(path.count == 33)
        #expect(abs(path.first!.lon - a.lon) < 1e-6 && abs(path.first!.lat - a.lat) < 1e-6)
        #expect(abs(path.last!.lon - b.lon) < 1e-6 && abs(path.last!.lat - b.lat) < 1e-6)
        // Europe to Japan bows north over Siberia.
        #expect(path.map(\.lat).max()! > 60)
    }
}

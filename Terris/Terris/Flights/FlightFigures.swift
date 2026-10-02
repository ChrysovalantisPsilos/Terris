//
//  FlightFigures.swift
//  Terris
//
//  Every figure the Flights tab shows, from plain values.
//

import Foundation
import SwiftUI

struct FlightRecord: Equatable, Sendable, Identifiable {
    var id: UUID
    var date: Date?
    var from: String
    var to: String
    var fromPoint: GeoPoint?
    var toPoint: GeoPoint?
    var fromCountry: String?
    var toCountry: String?
    var airline: String?
    var number: String?
    var km: Double
    var arrival: Date? = nil
    var fromCity: String? = nil
    var toCity: String? = nil
    var seatClass: SeatClass? = nil
    var seat: String? = nil
    var rating: Int = 0
    var notes: String? = nil

    /// Minutes in the air, when both times are known and in order.
    var minutes: Int? {
        guard let date, let arrival, arrival > date else { return nil }
        return Int(arrival.timeIntervalSince(date) / 60)
    }
}

/// Stored as its raw value on Flight.seatClass.
enum SeatClass: String, CaseIterable, Identifiable, Sendable {
    case economy = "Economy"
    case premiumEconomy = "Premium Economy"
    case business = "Business"
    case first = "First"

    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .economy: "Economy"
        case .premiumEconomy: "Premium economy"
        case .business: "Business"
        case .first: "First"
        }
    }
}

struct FlightFigures: Equatable, Sendable {
    struct YearSection: Equatable, Sendable, Identifiable {
        /// nil when the flight has no date.
        var year: Int?
        var rows: [FlightRecord]
        var km: Double
        var id: Int { year ?? 0 }
    }

    struct Route: Equatable, Sendable {
        var from: GeoPoint
        var to: GeoPoint
    }

    var count: Int
    var km: Double
    var airports: Int
    var countries: Int
    var sections: [YearSection]
    var routes: [Route]

    /// Earth's equatorial circumference in km.
    static let earthKm = 40_075.0

    /// How many times around the Earth, to one decimal.
    /// How many times around the Earth, to two decimals (19,200 km → 0.48).
    var timesAroundEarth: Double { (km / Self.earthKm * 100).rounded() / 100 }
    /// How far into the current lap (0…1), for the progress bar.
    var lapFraction: Double { timesAroundEarth - timesAroundEarth.rounded(.down) }
    /// The lap the bar runs towards (1× until the first full lap, then 2×…).
    var nextLap: Int { Int(timesAroundEarth.rounded(.down)) + 1 }

    static func compute(_ flights: [FlightRecord], calendar: Calendar = .current) -> FlightFigures {
        let sorted = flights.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        let airports = Set(flights.flatMap { [$0.from, $0.to] }.filter { !$0.isEmpty })
        let countries = Set(flights.flatMap { [$0.fromCountry, $0.toCountry] }.compactMap { $0 })

        var order: [Int?] = []
        var byYear: [Int?: [FlightRecord]] = [:]
        for f in sorted {
            let year = f.date.map { calendar.component(.year, from: $0) }
            if byYear[year] == nil { order.append(year) }
            byYear[year, default: []].append(f)
        }
        // Undated flights go last.
        order.sort { ($0 ?? Int.min) > ($1 ?? Int.min) }
        let sections = order.map { year in
            let rows = byYear[year] ?? []
            return YearSection(year: year, rows: rows, km: rows.reduce(0) { $0 + $1.km })
        }

        var seen = Set<String>()
        let routes = flights.compactMap { f -> Route? in
            guard let a = f.fromPoint, let b = f.toPoint else { return nil }
            // One arc per airport pair, whichever direction.
            let key = [f.from, f.to].sorted().joined(separator: "-")
            guard seen.insert(key).inserted else { return nil }
            return Route(from: a, to: b)
        }

        return FlightFigures(count: flights.count,
                             km: flights.reduce(0) { $0 + $1.km },
                             airports: airports.count,
                             countries: countries.count,
                             sections: sections,
                             routes: routes)
    }
}

extension Projection {
    /// Great-circle distance in km (haversine, mean Earth radius).
    static func distanceKm(_ a: GeoPoint, _ b: GeoPoint) -> Double {
        let r = 6371.0
        let φ1 = a.lat * .pi / 180, φ2 = b.lat * .pi / 180
        let dφ = φ2 - φ1, dλ = (b.lon - a.lon) * .pi / 180
        let h = sin(dφ / 2) * sin(dφ / 2) + cos(φ1) * cos(φ2) * sin(dλ / 2) * sin(dλ / 2)
        return r * 2 * atan2(h.squareRoot(), (1 - h).squareRoot())
    }

    /// Points along the great circle from a to b (inclusive), for drawing routes.
    static func greatCircle(from a: GeoPoint, to b: GeoPoint, steps: Int = 48) -> [GeoPoint] {
        func vec(_ p: GeoPoint) -> (Double, Double, Double) {
            let φ = p.lat * .pi / 180, λ = p.lon * .pi / 180
            return (cos(φ) * cos(λ), cos(φ) * sin(λ), sin(φ))
        }
        let (ax, ay, az) = vec(a), (bx, by, bz) = vec(b)
        let dot = max(-1, min(1, ax * bx + ay * by + az * bz))
        let ω = acos(dot)
        guard ω > 1e-9 else { return [a, b] }
        return (0...steps).map { i in
            let t = Double(i) / Double(steps)
            let s0 = sin((1 - t) * ω) / sin(ω), s1 = sin(t * ω) / sin(ω)
            let x = s0 * ax + s1 * bx, y = s0 * ay + s1 * by, z = s0 * az + s1 * bz
            return GeoPoint(lon: atan2(y, x) * 180 / .pi,
                            lat: atan2(z, (x * x + y * y).squareRoot()) * 180 / .pi)
        }
    }
}

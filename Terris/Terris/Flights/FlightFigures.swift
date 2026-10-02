//
//  FlightFigures.swift
//  Terris
//
//  Every figure the Flights tab shows, from plain values.
//

import Foundation

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
    var timesAroundEarth: Double { (km / Self.earthKm * 10).rounded() / 10 }

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

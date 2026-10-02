//
//  FlightDraft.swift
//  Terris
//
//  The add / edit flight form as plain values: what's being typed, whether
//  it can be saved and why not, and the airport search. Pure and tested
//  (FlightDraftTests).
//

import Foundation

struct FlightDraft: Equatable {
    /// nil while adding; the flight's id while editing.
    var id: UUID?
    var from: AirportRecord?
    var to: AirportRecord?
    var departure: Date
    var arrival: Date?
    var airline = ""
    var number = ""
    var seatClass: SeatClass = .economy
    var seat = ""
    var rating = 0
    var notes = ""

    enum Problem: Equatable {
        case missingRoute, sameAirport, arrivesBeforeDeparture
    }

    /// The first thing stopping a save, or nil when it can be saved.
    var problem: Problem? {
        guard let from, let to else { return .missingRoute }
        if from.iata == to.iata { return .sameAirport }
        if let arrival, arrival <= departure { return .arrivesBeforeDeparture }
        return nil
    }

    var canSave: Bool { problem == nil }

    var distanceKm: Double? {
        guard let from, let to, from.iata != to.iata else { return nil }
        return Projection.distanceKm(GeoPoint(lon: from.lon, lat: from.lat), GeoPoint(lon: to.lon, lat: to.lat))
    }

    var minutes: Int? {
        guard let arrival, arrival > departure else { return nil }
        return Int(arrival.timeIntervalSince(departure) / 60)
    }

    /// Stored status: a flight still ahead is "upcoming", otherwise "completed".
    func status(now: Date) -> String { departure > now ? "upcoming" : "completed" }

    mutating func swapAirports() { (from, to) = (to, from) }

    static func new(now: Date) -> FlightDraft { FlightDraft(id: nil, departure: now) }
}

enum AirportSearch {
    /// Code matches first (exact, then prefix), then city, then name or
    /// country, each alphabetical by city. Empty query → nothing.
    static func filter(_ airports: [AirportRecord], query: String, limit: Int = 8) -> [AirportRecord] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        func rank(_ a: AirportRecord) -> Int? {
            if a.iata.caseInsensitiveCompare(q) == .orderedSame { return 0 }
            if a.iata.range(of: q, options: options.union(.anchored)) != nil
                || a.icao.range(of: q, options: options.union(.anchored)) != nil { return 1 }
            if a.city.range(of: q, options: options.union(.anchored)) != nil { return 2 }
            if a.city.range(of: q, options: options) != nil { return 3 }
            if a.name.range(of: q, options: options) != nil
                || a.countryISO.caseInsensitiveCompare(q) == .orderedSame { return 4 }
            return nil
        }
        // Split into typed steps: as one chain the compiler times out.
        var ranked: [(airport: AirportRecord, rank: Int)] = []
        for airport in airports {
            if let r = rank(airport) { ranked.append((airport, r)) }
        }
        ranked.sort { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            return lhs.airport.city.localizedCompare(rhs.airport.city) == .orderedAscending
        }
        return ranked.prefix(limit).map { $0.airport }
    }
}

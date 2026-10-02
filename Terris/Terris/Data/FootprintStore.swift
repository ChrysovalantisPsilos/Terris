//
//  FootprintStore.swift
//  Terris
//
//  The one place that reads and writes the user's footprint in Core Data.
//  Views and figures never touch NSManagedObjectContext.
//
//  Country rows are created only when the user marks a country, so a new
//  device syncing over iCloud doesn't add 197 empty rows of its own. If two
//  devices ever create the same country, reads keep the most recently
//  changed row.
//

import CoreData
import Observation

@MainActor
@Observable
final class FootprintStore {
    /// Bumped on every change in the context (local edits and iCloud merges),
    /// so screens can reload with `.task(id: store.version)`.
    private(set) var version = 0
    /// The last write that failed, for the screen to show.
    var lastError: String?

    let catalog: [CountryEntry]
    private let context: NSManagedObjectContext
    private var observer: NSObjectProtocol?

    init(context: NSManagedObjectContext, catalog: [CountryEntry] = CountryData.all) {
        self.context = context
        self.catalog = catalog
        observer = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange, object: context, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.version += 1 }
        }
    }

    func entry(for iso: String) -> CountryEntry? {
        catalog.first { $0.isoCode == iso }
    }

    // MARK: Reads

    func countryRecords() -> [CountryRecord] {
        rowsByISO().values.map(Self.record)
    }

    func record(for iso: String) -> CountryRecord? {
        rowsByISO()[iso].map(Self.record)
    }

    func photoIdentifiers(for iso: String, limit: Int = 12) -> [String] {
        let req: NSFetchRequest<TravelPhoto> = TravelPhoto.fetchRequest()
        req.predicate = NSPredicate(format: "country.isoCode == %@ AND assetIdentifier != nil", iso)
        req.sortDescriptors = [NSSortDescriptor(key: "takenDate", ascending: false)]
        req.fetchLimit = limit
        return ((try? context.fetch(req)) ?? []).compactMap(\.assetIdentifier)
    }

    // MARK: Writes

    func setStatus(_ status: TravelStatus, for iso: String, now: Date = .now) {
        let row = findOrCreate(iso)
        guard row.status != status.rawValue else { return }
        row.status = status.rawValue
        row.statusChangedAt = now
        save()
    }

    func setFirstVisit(_ date: Date?, for iso: String) {
        findOrCreate(iso).firstVisitDate = date
        save()
    }

    func setLastVisit(_ date: Date?, for iso: String) {
        findOrCreate(iso).lastVisitDate = date
        save()
    }

    func setNotes(_ notes: String, for iso: String) {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        findOrCreate(iso).notes = trimmed.isEmpty ? nil : notes
        save()
    }

    func addCity(_ name: String, to iso: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let country = findOrCreate(iso)
        let existing = (country.cities as? Set<City>) ?? []
        guard !existing.contains(where: { $0.name?.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        let city = City(context: context)
        city.id = UUID()
        city.name = trimmed
        city.status = TravelStatus.visited.rawValue
        city.country = country
        save()
    }

    func removeCity(_ name: String, from iso: String) {
        guard let country = rowsByISO()[iso],
              let city = ((country.cities as? Set<City>) ?? []).first(where: { $0.name == name }) else { return }
        context.delete(city)
        save()
    }

    // MARK: Private

    private func rowsByISO() -> [String: Country] {
        let rows = (try? context.fetch(Country.fetchRequest())) ?? []
        var byISO: [String: Country] = [:]
        for row in rows {
            guard let iso = row.isoCode else { continue }
            if let kept = byISO[iso],
               (kept.statusChangedAt ?? .distantPast) >= (row.statusChangedAt ?? .distantPast) { continue }
            byISO[iso] = row
        }
        return byISO
    }

    private func findOrCreate(_ iso: String) -> Country {
        if let row = rowsByISO()[iso] { return row }
        let row = Country(context: context)
        row.id = UUID()
        row.isoCode = iso
        row.name = entry(for: iso)?.name ?? iso
        row.continent = entry(for: iso)?.continent
        row.status = TravelStatus.none.rawValue
        return row
    }

    private func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            context.rollback()
        }
    }

    private static func record(_ row: Country) -> CountryRecord {
        CountryRecord(
            iso: row.isoCode ?? "",
            status: TravelStatus(rawValue: row.status) ?? .none,
            statusChangedAt: row.statusChangedAt,
            firstVisit: row.firstVisitDate,
            lastVisit: row.lastVisitDate,
            notes: row.notes,
            cities: ((row.cities as? Set<City>) ?? []).compactMap(\.name).sorted(),
            photoCount: max(row.photos?.count ?? 0, Int(row.scannedPhotoCount)))
    }
}

extension FootprintStore {
    /// Earlier builds created a row for every country up front. Rows the user
    /// never touched are deleted, so they don't sync to iCloud.
    func pruneUntouchedRows() {
        let req: NSFetchRequest<Country> = Country.fetchRequest()
        req.predicate = NSPredicate(
            format: "status == 0 AND notes == nil AND firstVisitDate == nil AND lastVisitDate == nil AND cities.@count == 0 AND photos.@count == 0")
        let rows = (try? context.fetch(req)) ?? []
        guard !rows.isEmpty else { return }
        rows.forEach(context.delete)
        save()
    }
}

// MARK: - Flights

extension FootprintStore {
    func flightRecords() -> [FlightRecord] {
        let rows = (try? context.fetch(Flight.fetchRequest())) ?? []
        return rows.compactMap { f in
            guard let id = f.id else { return nil }
            func point(_ a: Airport?) -> GeoPoint? {
                guard let a, a.latitude != 0 || a.longitude != 0 else { return nil }
                return GeoPoint(lon: a.longitude, lat: a.latitude)
            }
            return FlightRecord(id: id, date: f.departureDate,
                                from: f.departureAirport?.iata ?? "", to: f.arrivalAirport?.iata ?? "",
                                fromPoint: point(f.departureAirport), toPoint: point(f.arrivalAirport),
                                fromCountry: f.departureAirport?.countryISO,
                                toCountry: f.arrivalAirport?.countryISO,
                                airline: f.airline, number: f.flightNumber, km: f.distanceKm,
                                arrival: f.arrivalDate,
                                fromCity: f.departureAirport?.city, toCity: f.arrivalAirport?.city,
                                seatClass: f.seatClass.flatMap(SeatClass.init(rawValue:)),
                                seat: f.seatNumber, rating: Int(f.rating), notes: f.notes)
        }
    }

    private func flight(id: UUID) -> Flight? {
        let req: NSFetchRequest<Flight> = Flight.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        return try? context.fetch(req).first
    }

    func deleteFlight(id: UUID) {
        guard let flight = flight(id: id) else { return }
        context.delete(flight)
        save()
    }
}

// MARK: - Photo scan

extension FootprintStore {
    /// Applies a finished scan. A country with photos counts as visited unless
    /// the user already said Lived; visit dates widen to cover the photos.
    /// Returns how many countries were newly added to the map.
    @discardableResult
    func applyScan(_ results: [ScannedCountry], references: [String: String] = [:], now: Date = .now) -> Int {
        var added = 0
        for result in results where entry(for: result.iso) != nil {
            let row = findOrCreate(result.iso)
            let status = TravelStatus(rawValue: row.status) ?? .none
            if status == .none || status == .wantToVisit {
                row.status = TravelStatus.visited.rawValue
                row.statusChangedAt = now
                added += 1
            }
            if let first = result.first {
                row.firstVisitDate = min(row.firstVisitDate ?? first, first)
            }
            if let last = result.last {
                row.lastVisitDate = max(row.lastVisitDate ?? last, last)
            }
            row.scannedPhotoCount = Int32(clamping: result.count)
            let existing = Set(((row.photos as? Set<TravelPhoto>) ?? []).compactMap(\.assetIdentifier))
            // Store the cross-device reference when there is one.
            for id in result.samples.map({ references[$0] ?? $0 }) where !existing.contains(id) {
                let photo = TravelPhoto(context: context)
                photo.id = UUID()
                photo.assetIdentifier = id
                photo.country = row
            }
        }
        save()
        return added
    }
}

// MARK: - Photo references

extension FootprintStore {
    /// Photo references still in a device's local form (see PhotoReferences).
    func localPhotoReferences() -> [String] {
        let req: NSFetchRequest<TravelPhoto> = TravelPhoto.fetchRequest()
        req.predicate = NSPredicate(format: "assetIdentifier != nil AND NOT (assetIdentifier BEGINSWITH %@)",
                                    PhotoReferences.cloudPrefix)
        return ((try? context.fetch(req)) ?? []).compactMap(\.assetIdentifier)
    }

    /// Swaps references (old → new); a photo whose new reference is already
    /// stored for the same country is removed instead, so none is doubled.
    func replacePhotoReferences(_ map: [String: String]) {
        guard !map.isEmpty else { return }
        let req: NSFetchRequest<TravelPhoto> = TravelPhoto.fetchRequest()
        req.predicate = NSPredicate(format: "assetIdentifier IN %@", Array(map.keys))
        guard let rows = try? context.fetch(req), !rows.isEmpty else { return }
        for row in rows {
            guard let old = row.assetIdentifier, let new = map[old] else { continue }
            let siblings = (row.country?.photos as? Set<TravelPhoto>) ?? []
            if siblings.contains(where: { $0 !== row && $0.assetIdentifier == new }) {
                context.delete(row)
            } else {
                row.assetIdentifier = new
            }
        }
        save()
    }
}

// MARK: - Flight form

extension FootprintStore {
    /// The form's values for an existing flight.
    func flightDraft(id: UUID) -> FlightDraft? {
        guard let f = flight(id: id) else { return nil }
        func record(_ a: Airport?) -> AirportRecord? {
            guard let a, let iata = a.iata else { return nil }
            return kAirportDatabase.first { $0.iata == iata }
                ?? AirportRecord(iata: iata, icao: a.icao ?? "", name: a.name ?? iata, city: a.city ?? "",
                                 countryISO: a.countryISO ?? "", lat: a.latitude, lon: a.longitude)
        }
        return FlightDraft(id: id, from: record(f.departureAirport), to: record(f.arrivalAirport),
                           departure: f.departureDate ?? .now, arrival: f.arrivalDate,
                           airline: f.airline ?? "", number: f.flightNumber ?? "",
                           seatClass: f.seatClass.flatMap(SeatClass.init(rawValue:)) ?? .economy,
                           seat: f.seatNumber ?? "", rating: Int(f.rating), notes: f.notes ?? "")
    }

    /// Adds or updates a flight. Returns false (and sets lastError) if it
    /// can't be saved.
    @discardableResult
    func saveFlight(_ draft: FlightDraft, now: Date = .now) -> Bool {
        guard draft.canSave, let from = draft.from, let to = draft.to else { return false }
        let flight: Flight
        if let id = draft.id, let existing = self.flight(id: id) {
            flight = existing
        } else {
            flight = Flight(context: context)
            flight.id = draft.id ?? UUID()
        }
        func clean(_ s: String) -> String? {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        flight.departureAirport = airport(from)
        flight.arrivalAirport = airport(to)
        flight.departureDate = draft.departure
        flight.arrivalDate = draft.arrival
        flight.airline = clean(draft.airline)
        flight.flightNumber = clean(draft.number)?.uppercased()
        flight.seatClass = draft.seatClass.rawValue
        flight.seatNumber = clean(draft.seat)?.uppercased()
        flight.rating = Float(draft.rating)
        flight.notes = clean(draft.notes)
        flight.distanceKm = draft.distanceKm ?? 0
        flight.status = draft.status(now: now)
        save()
        return lastError == nil
    }

    private func airport(_ rec: AirportRecord) -> Airport {
        let req: NSFetchRequest<Airport> = Airport.fetchRequest()
        req.predicate = NSPredicate(format: "iata == %@", rec.iata)
        req.fetchLimit = 1
        if let existing = try? context.fetch(req).first { return existing }
        let a = Airport(context: context)
        a.id = UUID()
        a.iata = rec.iata
        a.icao = rec.icao
        a.name = rec.name
        a.city = rec.city
        a.countryISO = rec.countryISO
        a.latitude = rec.lat
        a.longitude = rec.lon
        return a
    }

    func flightRecord(id: UUID) -> FlightRecord? {
        flightRecords().first { $0.id == id }
    }
}

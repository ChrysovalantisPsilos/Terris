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
            photoCount: row.photos?.count ?? 0)
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

//
//  Persistence.swift
//  Terris
//
//  Created by Chrysovalantis Psilos on 12/04/2026.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        // Seed a few sample countries for previews
        let sampleCountries: [(String, String, String)] = [
            ("Japan", "JP", "Asia"),
            ("France", "FR", "Europe"),
            ("Brazil", "BR", "South America")
        ]
        for (name, iso, continent) in sampleCountries {
            let c = Country(context: viewContext)
            c.id = UUID()
            c.name = name
            c.isoCode = iso
            c.continent = continent
            c.status = TravelStatus.visited.rawValue
        }
        try? viewContext.save()
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Terris")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved CoreData error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        if !inMemory {
            seedCountriesIfNeeded()
        }
    }

    // MARK: - Seeding

    private func seedCountriesIfNeeded() {
        let ctx = container.viewContext
        let req: NSFetchRequest<Country> = Country.fetchRequest()
        req.fetchLimit = 1
        guard (try? ctx.count(for: req)) == 0 else { return }

        let countries = CountryData.all
        for entry in countries {
            let c = Country(context: ctx)
            c.id = UUID()
            c.name = entry.name
            c.isoCode = entry.isoCode
            c.continent = entry.continent
            c.status = TravelStatus.none.rawValue
            c.rating = 0
        }
        try? ctx.save()
    }

    func save() {
        let ctx = container.viewContext
        if ctx.hasChanges {
            try? ctx.save()
        }
    }
}

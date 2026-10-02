//
//  Persistence.swift
//  Terris
//
//  Created by Chrysovalantis Psilos on 12/04/2026.
//

import CoreData

struct PersistenceController {
    /// Unit tests run inside the app; they get an in-memory store with no
    /// iCloud, so a test run never syncs or waits on CloudKit.
    static let shared = PersistenceController(
        inMemory: ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil)

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
            c.statusChangedAt = .now
        }
        try? viewContext.save()
        return result
    }()

    let container: NSPersistentCloudKitContainer

    /// One model for every container: tests make several in-memory stores,
    /// and Core Data can't match a class to an entity if the model loads twice.
    private static let model: NSManagedObjectModel = {
        let url = Bundle.main.url(forResource: "Terris", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: url)!
    }()

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Terris", managedObjectModel: Self.model)
        if inMemory {
            let description = container.persistentStoreDescriptions.first!
            description.url = URL(fileURLWithPath: "/dev/null")
            // Previews and tests never talk to iCloud.
            description.cloudKitContainerOptions = nil
        }
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved CoreData error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}

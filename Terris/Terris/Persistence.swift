//
//  Persistence.swift
//  Terris
//
//  Created by Chrysovalantis Psilos on 12/04/2026.
//

import CoreData

struct PersistenceController {
    /// Unit tests run inside the app, and UI tests launch it with
    /// "-uiTesting"; both get an in-memory store with no iCloud, so a test run
    /// never syncs or waits on CloudKit. (CI builds are unsigned, without the
    /// iCloud entitlement, and CloudKit stops the app when asked for a named
    /// container it isn't entitled to.)
    static let shared = PersistenceController(
        inMemory: ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.arguments.contains("-uiTesting"))

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
        let description = container.persistentStoreDescriptions.first!
        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
            // Previews and tests never talk to iCloud.
            description.cloudKitContainerOptions = nil
        } else {
            // The user's private database in the app's container (named, not inferred).
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: Self.cloudKitContainer)
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved CoreData error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        #if DEBUG
        // CloudKit creates record types lazily, as data syncs. To create the
        // whole schema in the Development environment at once (then deploy it
        // to Production in the CloudKit Console), tick "-initCloudKitSchema" in
        // the scheme's Run arguments and run once on a device signed in to iCloud.
        if !inMemory, ProcessInfo.processInfo.arguments.contains("-initCloudKitSchema") {
            do {
                try container.initializeCloudKitSchema(options: [])
                print("CloudKit schema: created in the Development environment.")
            } catch {
                print("CloudKit schema: failed: \(error)")
            }
        }
        #endif
    }

    static let cloudKitContainer = "iCloud.com.chrysovalantis.Terris"
}

//
//  TerrisApp.swift
//  Terris
//
//  Created by Chrysovalantis Psilos on 12/04/2026.
//

import SwiftUI
import CoreData

@main
struct TerrisApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            RootAdaptiveView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(.dark)
        }
    }
}

//
//  TerrisApp.swift
//  Terris
//

import SwiftUI
import CoreData

@main
struct TerrisApp: App {
    private let persistence = PersistenceController.shared
    @State private var store: FootprintStore
    @State private var router = AppRouter()
    @State private var isLaunching = true

    init() {
        let store = FootprintStore(context: PersistenceController.shared.container.viewContext)
        store.pruneUntouchedRows()
        _store = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environment(store)
                    .environment(router)
                    // The flight screens still read Core Data directly.
                    .environment(\.managedObjectContext, persistence.container.viewContext)
                    .environment(\.isLaunching, isLaunching)

                if isLaunching {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                // Long enough for the animated mark; brief with Reduce Motion.
                let wait = UIAccessibility.isReduceMotionEnabled ? 0.6 : LaunchScreenView.duration
                try? await Task.sleep(for: .seconds(wait))
                withAnimation(.easeInOut(duration: 0.4)) { isLaunching = false }
            }
            .task {
                // Photos found on this device become references every
                // device can open (iCloud Photos), once.
                await PhotoReferences.upgrade(in: store)
            }
        }
    }
}

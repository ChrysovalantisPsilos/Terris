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

                if isLaunching {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation(.easeInOut(duration: 0.4)) { isLaunching = false }
            }
        }
    }
}

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
    @State private var isLaunching = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootAdaptiveView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .preferredColorScheme(.dark)

                if isLaunching {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .preferredColorScheme(.dark)
            .task {
                // Hold splash for 2.2s then fade out
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                withAnimation(.easeInOut(duration: 0.5)) {
                    isLaunching = false
                }
            }
        }
    }
}

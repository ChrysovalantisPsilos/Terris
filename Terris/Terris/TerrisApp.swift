//
//  TerrisApp.swift
//  Terris
//
//  Created by Chrysovalantis Psilos on 12/04/2026.
//

import SwiftUI
import CoreData

// Global theme key readable anywhere via @AppStorage
extension String {
    static let themeKey = "appTheme" // "system" | "light" | "dark"
}

@main
struct TerrisApp: App {
    let persistenceController = PersistenceController.shared
    @State private var isLaunching = true
    @AppStorage(.themeKey) private var theme: String = "dark"

    var colorScheme: ColorScheme? {
        switch theme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil   // system
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootAdaptiveView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)

                if isLaunching {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .preferredColorScheme(colorScheme)
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

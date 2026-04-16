//
//  TerrisApp.swift
//  Terris
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

                if isLaunching {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                withAnimation(.easeInOut(duration: 0.5)) {
                    isLaunching = false
                }
            }
        }
    }
}

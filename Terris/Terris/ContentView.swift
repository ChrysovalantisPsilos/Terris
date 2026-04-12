//
//  ContentView.swift
//  Terris
//
//  This file is kept as a preview helper. The app entry point uses RootAdaptiveView.
//

import SwiftUI
import CoreData

struct ContentView: View {
    var body: some View {
        RootAdaptiveView()
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

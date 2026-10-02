//
//  RootView.swift
//  Terris
//
//  Two destinations, Map and Flights, plus Search in the system's search
//  slot. On iPhone a floating Liquid Glass tab bar; on iPad a sidebar.
//

import SwiftUI

struct RootView: View {
    @Environment(FootprintStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView {
            Tab("Map", systemImage: "globe.europe.africa.fill") {
                MapScreen()
            }
            Tab("Flights", systemImage: "airplane") {
                NavigationStack { FlightTrackerView() }
            }
            Tab(role: .search) {
                SearchScreen()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Theme.accent)
        .sheet(item: $router.country) { open in
            CountryScreen(iso: open.iso, store: store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $router.showingImport) {
            PhotoImportView()
        }
    }
}

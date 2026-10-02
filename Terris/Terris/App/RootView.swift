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
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var showingOnboarding = false

    var body: some View {
        @Bindable var router = router
        TabView {
            Tab("Map", systemImage: "globe.europe.africa.fill") {
                MapScreen()
            }
            Tab("Flights", systemImage: "airplane") {
                FlightsScreen()
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
            ScanScreen()
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            ScanScreen { hasOnboarded = true }
        }
        .onAppear {
            guard !hasOnboarded else { return }
            // People who already marked countries skip the first-launch scan.
            if store.countryRecords().contains(where: { $0.status != .none }) {
                hasOnboarded = true
            } else {
                showingOnboarding = true
            }
        }
    }
}

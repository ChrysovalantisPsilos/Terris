//
//  RootView.swift
//  Terris
//
//  Two destinations, Map and Flights, plus Search in the system's search
//  slot. On iPhone a floating Liquid Glass tab bar; on iPad a sidebar.
//  First launch runs the photo scan, then the five-card tour (once).
//

import SwiftUI

struct RootView: View {
    @Environment(FootprintStore.self) private var store
    @Environment(AppRouter.self) private var router
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @AppStorage("hasSeenTour") private var hasSeenTour = false
    @State private var showingOnboarding = false
    @State private var showingTour = false
    /// True while the launch animation plays; first-run screens wait for it.
    @Environment(\.isLaunching) private var isLaunching

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
        .fullScreenCover(isPresented: $showingOnboarding, onDismiss: {
            if !hasSeenTour { showingTour = true }
        }) {
            ScanScreen { hasOnboarded = true }
        }
        .fullScreenCover(isPresented: $showingTour) {
            TourScreen { hasSeenTour = true }
        }
        .onChange(of: isLaunching, initial: true) { _, launching in
            guard !launching else { return }
            presentFirstRunScreens()
        }
    }

    /// The first-launch scan, then the tour, each once; after the splash.
    private func presentFirstRunScreens() {
        guard !hasOnboarded else {
            // People who onboarded before the tour existed see it once.
            if !hasSeenTour { showingTour = true }
            return
        }
        // People who already marked countries skip the first-launch scan.
        if store.countryRecords().contains(where: { $0.status != .none }) {
            hasOnboarded = true
            if !hasSeenTour { showingTour = true }
        } else {
            showingOnboarding = true
        }
    }
}

extension EnvironmentValues {
    /// Set by the app while the launch animation is on screen.
    @Entry var isLaunching = false
}

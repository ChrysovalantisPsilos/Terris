//
//  RootAdaptiveView.swift
//  Terris
//
//  Adapts between:
//  - iPad/macOS: NavigationSplitView with left sidebar, center globe, right detail panel
//  - iPhone: TabView with globe as main tab
//

import SwiftUI
import CoreData

struct RootAdaptiveView: View {
    @State private var globeVM = GlobeViewModel()
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Country.name, ascending: true)]
    ) private var countries: FetchedResults<Country>

    @State private var showingSearch = false
    @State private var showingImport = false
    @State private var showingStats = false
    @State private var showingTimeline = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    // Listen for globe taps
    @State private var tapListenerCountry: Country?

    var body: some View {
        if hSizeClass == .regular {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    // MARK: - iPad / macOS Layout

    private var iPadLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Left sidebar
            LeftSidebarView(globeVM: globeVM)
                .navigationTitle("Terris")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { topBarTools }
        } content: {
            // Center globe
            ZStack(alignment: .topLeading) {
                globeContent
                    .ignoresSafeArea()
                // Status legend
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(TravelStatus.allCases.filter { $0 != .none }, id: \.id) { status in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(status.color)
                                .frame(width: 10, height: 10)
                            Text(status.label)
                                .font(.caption2.weight(.medium))
                        }
                    }
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding([.leading, .top], 14)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { globeTools }
        } detail: {
            // Right detail panel
            detailPanel
        }
        .onReceive(NotificationCenter.default.publisher(for: .globeCountryTapped)) { note in
            if let iso = note.userInfo?["isoCode"] as? String {
                let req: NSFetchRequest<Country> = Country.fetchRequest()
                req.predicate = NSPredicate(format: "isoCode == %@", iso)
                req.fetchLimit = 1
                if let c = try? ctx.fetch(req).first {
                    globeVM.selectCountry(c)
                }
            }
        }
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        TabView {
            // Globe tab
            NavigationStack {
                ZStack(alignment: .bottom) {
                    globeContent
                        .ignoresSafeArea()
                    // Status legend overlay (top-left)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(TravelStatus.allCases.filter { $0 != .none }, id: \.id) { status in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(status.color)
                                    .frame(width: 10, height: 10)
                                Text(status.label)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.leading, 12)
                    .padding(.top, 56)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    // Bottom sheet for selected country
                    if let country = globeVM.selectedCountry {
                        BottomDetailSheet(country: country, globeVM: globeVM)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { globeTools }
                .toolbar { topBarTools }
            }
            .tabItem { Label("Globe", systemImage: "globe") }

            // Timeline tab
            NavigationStack {
                TripTimelineView()
            }
            .tabItem { Label("Timeline", systemImage: "clock.fill") }

            // Stats tab
            NavigationStack {
                StatsDashboardView()
            }
            .tabItem { Label("Stats", systemImage: "chart.pie.fill") }
        }
        .onReceive(NotificationCenter.default.publisher(for: .globeCountryTapped)) { note in
            if let iso = note.userInfo?["isoCode"] as? String {
                let req: NSFetchRequest<Country> = Country.fetchRequest()
                req.predicate = NSPredicate(format: "isoCode == %@", iso)
                req.fetchLimit = 1
                if let c = try? ctx.fetch(req).first {
                    globeVM.selectCountry(c)
                }
            }
        }
    }

    // MARK: - Shared Globe Content

    private var globeContent: some View {
        GlobeView(viewModel: globeVM, countries: Array(countries))
    }

    // MARK: - Detail Panel (iPad right column)

    @ViewBuilder
    private var detailPanel: some View {
        if let country = globeVM.selectedCountry {
            NavigationStack {
                PlaceDetailView(country: country)
                    .navigationTitle(country.name ?? "Country")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                withAnimation { globeVM.selectCountry(nil) }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
            }
        } else {
            emptyDetailPanel
        }
    }

    private var emptyDetailPanel: some View {
        VStack(spacing: 16) {
            Image(systemName: "cursorarrow.click")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Select a Country")
                .font(.title3.bold())
            Text("Tap any country on the globe to view details, set your travel status, and add notes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Toolbar items

    @ToolbarContentBuilder
    private var topBarTools: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showingSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .sheet(isPresented: $showingSearch) {
                SearchView(globeVM: globeVM)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showingImport = true
            } label: {
                Image(systemName: "photo.badge.plus")
            }
            .sheet(isPresented: $showingImport) {
                PhotoImportView()
            }
        }
    }

    @ToolbarContentBuilder
    private var globeTools: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 14) {
                Button {
                    showingTimeline = true
                } label: {
                    Image(systemName: "clock.fill")
                }
                Button {
                    showingStats = true
                } label: {
                    Image(systemName: "chart.pie.fill")
                }
            }
            .sheet(isPresented: $showingTimeline) {
                TripTimelineView()
            }
            .sheet(isPresented: $showingStats) {
                StatsDashboardView()
            }
        }
    }
}

// MARK: - iPhone Bottom Detail Sheet

struct BottomDetailSheet: View {
    let country: Country
    var globeVM: GlobeViewModel
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Handle / collapse bar
            HStack {
                Capsule()
                    .fill(Color(.tertiaryLabel))
                    .frame(width: 36, height: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .onTapGesture { withAnimation(.spring()) { isExpanded.toggle() } }

            if isExpanded {
                PlaceDetailView(country: country)
                    .frame(maxHeight: 500)
            } else {
                // Collapsed summary
                HStack(spacing: 12) {
                    Text(flagEmoji(for: country.isoCode ?? ""))
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(country.name ?? "").font(.headline)
                        let s = TravelStatus(rawValue: country.status) ?? .none
                        Text(s.label).font(.caption).foregroundStyle(s.color)
                    }
                    Spacer()
                    Button {
                        withAnimation { globeVM.selectCountry(nil) }
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.25), radius: 20, y: -4)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: globeVM.selectedCountry?.id)
    }

    private func flagEmoji(for isoCode: String) -> String {
        guard isoCode.count == 2 else { return "🏳️" }
        let base: UInt32 = 127397
        var result = ""
        for scalar in isoCode.uppercased().unicodeScalars {
            guard let s = Unicode.Scalar(base + scalar.value) else { continue }
            result.append(Character(s))
        }
        return result.isEmpty ? "🏳️" : result
    }
}

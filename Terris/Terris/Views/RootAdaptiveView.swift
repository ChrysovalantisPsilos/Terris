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
   @AppStorage("mapAppearance") private var mapAppearanceRaw: String = MapAppearance.hybridFlyover.rawValue

   private var mapAppearance: MapAppearance {
       MapAppearance(rawValue: mapAppearanceRaw) ?? .hybridFlyover
   }
   
   @FetchRequest(
       sortDescriptors: [NSSortDescriptor(keyPath: \Country.name, ascending: true)]
   ) private var countries: FetchedResults<Country>

   @FetchRequest(
       sortDescriptors: [NSSortDescriptor(keyPath: \City.name, ascending: true)],
       predicate: NSPredicate(format: "status != 0")
   ) private var visitedCities: FetchedResults<City>

   @FetchRequest(
       sortDescriptors: [NSSortDescriptor(keyPath: \Flight.departureDate, ascending: false)]
   ) private var flights: FetchedResults<Flight>
   
   @State private var showingSearch = false
   @State private var showingImport = false
   @State private var columnVisibility = NavigationSplitViewVisibility.all
   
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
           LeftSidebarView(globeVM: globeVM)
               .navigationTitle("Terris")
               .navigationBarTitleDisplayMode(.inline)
               .toolbar {
                   ToolbarItem(placement: .topBarLeading) {
                       Button { showingSearch = true } label: {
                           Image(systemName: "magnifyingglass")
                       }
                       .sheet(isPresented: $showingSearch) {
                           SearchView(globeVM: globeVM)
                       }
                   }
               }
       } content: {
           ZStack(alignment: .topLeading) {
               globeContent.ignoresSafeArea()
               // Status legend top-left
               VStack(alignment: .leading, spacing: 5) {
                   ForEach(TravelStatus.allCases.filter { $0 != .none }, id: \.id) { status in
                       HStack(spacing: 6) {
                           Circle().fill(status.color).frame(width: 10, height: 10)
                           Text(status.label).font(.caption2.weight(.medium))
                       }
                   }
               }
               .padding(10)
               .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
               .padding([.leading, .top], 14)
               // Map style picker — bottom trailing
               VStack {
                   Spacer()
                   HStack {
                       Spacer()
                       mapStylePicker
                           .padding(14)
                   }
               }
           }
           .navigationBarTitleDisplayMode(.inline)
           .toolbar {
               ToolbarItem(placement: .topBarTrailing) {
                   HStack(spacing: 16) {
                       Button { showingImport = true } label: {
                           Label("Import", systemImage: "photo.badge.plus")
                       }
                       .sheet(isPresented: $showingImport) { PhotoImportView() }
                       NavigationLink {
                           FlightTrackerView()
                       } label: {
                           Label("Flights", systemImage: "airplane")
                       }
                       NavigationLink {
                           TripTimelineView()
                       } label: {
                           Label("Timeline", systemImage: "clock.fill")
                       }
                       NavigationLink {
                           StatsDashboardView()
                       } label: {
                           Label("Stats", systemImage: "chart.pie.fill")
                       }
                   }
               }
           }
       } detail: {
           detailPanel
       }
       .onReceive(NotificationCenter.default.publisher(for: .globeCountryTapped)) { note in
           if let iso = note.userInfo?["isoCode"] as? String {
               let req: NSFetchRequest<Country> = Country.fetchRequest()
               req.predicate = NSPredicate(format: "isoCode == %@", iso)
               req.fetchLimit = 1
               if let c = try? ctx.fetch(req).first { globeVM.selectCountry(c) }
           }
       }
   }
   
   // MARK: - iPhone Layout
   
   private var iPhoneLayout: some View {
       TabView {
           // Globe tab
           NavigationStack {
               ZStack(alignment: .bottom) {
                   globeContent.ignoresSafeArea()
                   // Status legend top-left
                   VStack(alignment: .leading, spacing: 4) {
                       ForEach(TravelStatus.allCases.filter { $0 != .none }, id: \.id) { status in
                           HStack(spacing: 6) {
                               Circle().fill(status.color).frame(width: 10, height: 10)
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
                   // Map style picker bottom-right
                   VStack {
                       Spacer()
                       HStack {
                           Spacer()
                           mapStylePicker.padding(14)
                       }
                       if globeVM.selectedCountry != nil { Color.clear.frame(height: 100) }
                   }
                   // Bottom sheet for selected country
                   if let country = globeVM.selectedCountry {
                       BottomDetailSheet(country: country, globeVM: globeVM)
                   }
               }
               .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingSearch = true } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .sheet(isPresented: $showingSearch) {
                            SearchView(globeVM: globeVM)
                        }
                    }
               }
           }
           .tabItem { Label("Globe", systemImage: "globe") }

           // Flights tab
           NavigationStack { FlightTrackerView() }
               .tabItem { Label("Flights", systemImage: "airplane") }

           // Timeline tab
           NavigationStack { TripTimelineView() }
               .tabItem { Label("Timeline", systemImage: "clock.fill") }

           // Stats tab
           NavigationStack { StatsDashboardView() }
               .tabItem { Label("Stats", systemImage: "chart.pie.fill") }

           // Import tab
           NavigationStack { PhotoImportView() }
               .tabItem { Label("Import", systemImage: "photo.badge.plus") }
       }
       .onReceive(NotificationCenter.default.publisher(for: .globeCountryTapped)) { note in
           if let iso = note.userInfo?["isoCode"] as? String {
               let req: NSFetchRequest<Country> = Country.fetchRequest()
               req.predicate = NSPredicate(format: "isoCode == %@", iso)
               req.fetchLimit = 1
               if let c = try? ctx.fetch(req).first { globeVM.selectCountry(c) }
           }
       }
   }
   
   // MARK: - Shared Globe Content

   private var globeContent: some View {
       GlobeView(viewModel: globeVM,
                 countries: Array(countries),
                 cities: Array(visitedCities),
                 flights: Array(flights),
                 mapAppearance: mapAppearance)
   }

   // MARK: - Map Style Picker Button

   private var mapStylePicker: some View {
       Menu {
           ForEach(MapAppearance.allCases, id: \.rawValue) { style in
               Button {
                   mapAppearanceRaw = style.rawValue
               } label: {
                   Label(style.rawValue, systemImage: style.icon)
               }
               .disabled(style.rawValue == mapAppearanceRaw)
           }
       } label: {
           Image(systemName: mapAppearance.icon)
               .font(.system(size: 14, weight: .semibold))
               .foregroundStyle(.primary)
               .frame(width: 36, height: 36)
               .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
       }
   }
   
   // MARK: - Detail Panel (iPad right column)

   @ViewBuilder
   private var detailPanel: some View {
       if let country = globeVM.selectedCountry {
           NavigationStack {
               CountryDetailPage(country: country)
                   .toolbar {
                       ToolbarItem(placement: .topBarTrailing) {
                           Button { withAnimation { globeVM.selectCountry(nil) } } label: {
                               Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
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
           Image(systemName: "cursorarrow.click").font(.system(size: 48)).foregroundStyle(.tertiary)
           Text("Select a Country").font(.title3.bold())
           Text("Tap any country on the globe to view details, set your travel status, and add memories.")
               .font(.subheadline).foregroundStyle(.secondary)
               .multilineTextAlignment(.center).padding(.horizontal, 32)
       }
       .frame(maxWidth: .infinity, maxHeight: .infinity)
       .background(Color(.systemGroupedBackground))
   }
}

// MARK: - iPhone Bottom Popup (tappable → full page)

struct BottomDetailSheet: View {
   let country: Country
   var globeVM: GlobeViewModel
   @State private var showDetail = false

   var body: some View {
       Button {
           showDetail = true
       } label: {
           HStack(spacing: 14) {
               Text(flagEmoji(for: country.isoCode ?? ""))
                   .font(.system(size: 36))
               VStack(alignment: .leading, spacing: 3) {
                   Text(country.name ?? "")
                       .font(.headline)
                       .foregroundStyle(.primary)
                   let s = TravelStatus(rawValue: country.status) ?? .none
                   HStack(spacing: 5) {
                       Circle().fill(s.color).frame(width: 8, height: 8)
                       Text(s.label).font(.caption).foregroundStyle(s.color)
                   }
               }
               Spacer()
               HStack(spacing: 6) {
                   Text("View details")
                       .font(.caption.weight(.medium))
                       .foregroundStyle(.secondary)
                   Image(systemName: "chevron.right")
                       .font(.caption.weight(.semibold))
                       .foregroundStyle(.secondary)
               }
               Button {
                   withAnimation(.spring()) { globeVM.selectCountry(nil) }
               } label: {
                   Image(systemName: "xmark.circle.fill")
                       .font(.title3)
                       .foregroundStyle(Color(.tertiaryLabel))
               }
               .buttonStyle(.plain)
           }
           .padding(.horizontal, 18)
           .padding(.vertical, 14)
       }
       .buttonStyle(.plain)
       .background(
           RoundedRectangle(cornerRadius: 22, style: .continuous)
               .fill(.regularMaterial)
               .shadow(color: .black.opacity(0.18), radius: 16, y: -4)
       )
       .padding(.horizontal, 10)
       .padding(.bottom, 6)
       .transition(.move(edge: .bottom).combined(with: .opacity))
       .animation(.spring(response: 0.4, dampingFraction: 0.75), value: country.objectID)
       .sheet(isPresented: $showDetail) {
           NavigationStack {
               CountryDetailPage(country: country)
           }
       }
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

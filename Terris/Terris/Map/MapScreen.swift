//
//  MapScreen.swift
//  Terris
//
//  The Map tab. Three layouts of the same figures; the user picks one from
//  the toolbar menu and the choice is remembered:
//  - Globe (default): the globe with a headline chip and a pull-up panel.
//  - Journal: a scrolling page with the flat map as a card.
//  - Atlas: the flat map on top and a country list below.
//

import SwiftUI

struct MapScreen: View {
    @Environment(FootprintStore.self) private var store
    @Environment(AppRouter.self) private var router
    @AppStorage("mapLayout") private var layout: MapLayout = .globe
    @Environment(\.motionEnabled) private var motionEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model: MapModel?
    @State private var effects = MapEffects.none
    @State private var showingGuide = false

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    content(model.figures)
                } else {
                    Theme.canvas
                }
            }
            .background(Theme.canvas.ignoresSafeArea())
            .toolbar { toolbar }
            .navigationTitle(layout == .journal ? Text("My World") : Text(""))
            .navigationBarTitleDisplayMode(layout == .journal ? .large : .inline)
        }
        .task(id: store.version) {
            let firstLoad = model == nil
            if model == nil { model = MapModel(store: store) }
            let before = model?.figures.statusByISO ?? [:]
            withAnimation(Theme.spring) { model?.load() }
            guard motionEnabled, !reduceMotion, let after = model?.figures.statusByISO else { return }
            if firstLoad {
                // The marked countries fill in, west to east, on first show.
                effects.fillStart = .now
            } else {
                // Countries that just changed (marked on their page, or added
                // by a scan) pulse once.
                let now = Date.now
                let changed = MapEffects.changed(from: before, to: after)
                guard !changed.isEmpty else { return }
                effects.pulses = effects.pulses.filter { now.timeIntervalSince($0.value) < MapEffects.pulseDuration }
                for iso in changed { effects.pulses[iso] = now }
            }
        }
        .sheet(isPresented: $showingGuide) { GuideScreen() }
    }

    @ViewBuilder
    private func content(_ figures: MapFigures) -> some View {
        Group {
            switch layout {
            case .globe:
                GlobeLayout(figures: figures, effects: effects, onSelect: { router.open($0) }, onScan: { scan() })
            case .journal:
                JournalLayout(figures: figures, effects: effects, onSelect: { router.open($0) }, onScan: { scan() })
            case .atlas:
                AtlasLayout(figures: figures, effects: effects, onSelect: { router.open($0) }, onScan: { scan() })
            }
        }
        .id(layout)
        .transition(.opacity.combined(with: .scale(scale: 0.985)))
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { showingGuide = true } label: {
                Label("How Terris works", systemImage: "questionmark.circle")
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button(action: scan) {
                Label("Find countries in my photos", systemImage: "photo.badge.magnifyingglass")
            }
            Menu {
                Picker(selection: $layout.animation(Theme.spring)) {
                    ForEach(MapLayout.allCases) { option in
                        Label(option.title, systemImage: option.systemImage).tag(option)
                    }
                } label: {
                    Text("Layout")
                }
            } label: {
                Label("Layout", systemImage: "square.3.layers.3d")
            }
        }
    }

    private func scan() { router.showingImport = true }
}

// MARK: - Globe

private struct GlobeLayout: View {
    let figures: MapFigures
    let effects: MapEffects
    let onSelect: (String) -> Void
    let onScan: () -> Void

    @Environment(\.motionEnabled) private var motionEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Where the globe rests: Europe and Africa in view.
    private static let home = GeoPoint(lon: 15, lat: 30)
    @State private var camera = GlobeCamera(center: GlobeLayout.home)
    @State private var didIntro = false
    @State private var expanded = false

    private var animate: Bool { motionEnabled && !reduceMotion }

    private let collapsedHeight: CGFloat = 300

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                Color.clear.frame(height: 96)
                GlobeMap(statusByISO: figures.statusByISO,
                         center: Binding(get: { camera.center }, set: { camera.set($0) }),
                         effects: effects,
                         onSelect: { select($0) },
                         onFling: { target in
                             camera.turn(to: target, duration: 0.9, animated: animate, curve: Motion.easeOutCubic)
                         })
                    .padding(.horizontal, 12)
                    .frame(maxHeight: .infinity)
                Color.clear.frame(height: collapsedHeight - 24)
            }

            HStack(spacing: 14) {
                WorldRing(fraction: figures.fraction, percent: figures.percent, size: 52)
                VStack(alignment: .leading, spacing: 6) {
                    HeadlineText(figures: figures)
                    StatusLegend(figures: figures)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .floatingGlass()
            .padding(.horizontal, 16)
            .padding(.top, 4)

            PullUpPanel(expanded: $expanded, collapsedHeight: collapsedHeight) {
                VStack(alignment: .leading, spacing: 16) {
                    // An empty map leads with the hint, so its button sits above the tab bar.
                    if figures.beenTo + figures.wantTo == 0 {
                        MapEmptyHint(onScan: onScan)
                    }
                    SectionTitle("Continents")
                    ContinentGrid(continents: figures.continents)
                    if figures.beenTo + figures.wantTo > 0 {
                        if !figures.recent.isEmpty {
                            SectionTitle("Recently added")
                            CountryListCard(rows: figures.recent, onSelect: onSelect)
                        }
                        if !figures.wishlist.isEmpty {
                            SectionTitle("Want to go") { Text("\(figures.wantTo)") }
                            CountryListCard(rows: figures.wishlist, onSelect: onSelect)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            // A short spin into place the first time the globe shows.
            guard !didIntro else { return }
            didIntro = true
            guard animate else { return }
            camera.set(GeoPoint(lon: Self.home.lon - 70, lat: Self.home.lat - 10))
            camera.turn(to: Self.home, duration: 1.4, animated: true)
        }
    }

    /// Turns the globe to centre the tapped country, then opens it.
    private func select(_ iso: String) {
        guard animate, let target = WorldShapes.shared.centroid(of: iso) else {
            onSelect(iso)
            return
        }
        let turn = camera.turn(to: GeoPoint(lon: target.lon, lat: min(max(target.lat, -60), 60)),
                               duration: 0.45, animated: true)
        Task {
            await turn.value
            onSelect(iso)
        }
    }
}

/// A bottom panel that rests at `collapsedHeight` and pulls up to most of the
/// screen. Drag the handle area, or tap it, to move it.
struct PullUpPanel<Content: View>: View {
    @Binding var expanded: Bool
    let collapsedHeight: CGFloat
    @ViewBuilder var content: () -> Content

    @GestureState private var drag: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let full = geo.size.height * 0.9
            let base = expanded ? full : collapsedHeight
            let height = min(max(base - drag, collapsedHeight * 0.8), full)
            VStack(spacing: 0) {
                Capsule()
                    .fill(Theme.muted.opacity(0.4))
                    .frame(width: 38, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(Theme.spring) { expanded.toggle() } }
                    .gesture(
                        DragGesture()
                            .updating($drag) { value, state, _ in state = value.translation.height }
                            .onEnded { value in
                                // Where the flick would carry it decides, not just how far it moved.
                                let travel = value.predictedEndTranslation.height
                                withAnimation(Motion.spring) {
                                    if travel < -60 { expanded = true }
                                    if travel > 60 { expanded = false }
                                }
                            })
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(expanded ? Text("Collapse") : Text("Expand"))
                ScrollView {
                    content()
                }
                .scrollIndicators(.hidden)
            }
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous)
                    .fill(Theme.canvas)
                    .shadow(color: .black.opacity(0.08), radius: 16, y: -4)
                    .ignoresSafeArea(edges: .bottom))
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

// MARK: - Journal

private struct JournalLayout: View {
    let figures: MapFigures
    let effects: MapEffects
    let onSelect: (String) -> Void
    let onScan: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(figures.beenTo)")
                                .font(.system(size: 64, weight: .bold).monospacedDigit())
                                .foregroundStyle(Theme.ink)
                                .contentTransition(.numericText(value: Double(figures.beenTo)))
                            Text("countries of \(figures.total)")
                                .font(.headline).foregroundStyle(Theme.ink)
                            Text("\(figures.percent)% of the world · ^[\(figures.cityCount) city](inflect: true)")
                                .font(.subheadline).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        WorldRing(fraction: figures.fraction, percent: figures.percent, size: 92, lineWidth: 10)
                    }
                    FlatMap(statusByISO: figures.statusByISO, effects: effects, onSelect: onSelect)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    StatusLegend(figures: figures)
                }
                .card()

                if figures.beenTo + figures.wantTo == 0 {
                    MapEmptyHint(onScan: onScan)
                }
                SectionTitle("Continents")
                ContinentRows(continents: figures.continents)
                if !figures.recent.isEmpty {
                    SectionTitle("Recently added")
                    CountryListCard(rows: figures.recent, onSelect: onSelect)
                }
                if !figures.wishlist.isEmpty {
                    SectionTitle("Want to go") { Text("\(figures.wantTo)") }
                    CountryListCard(rows: figures.wishlist, onSelect: onSelect)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Atlas

private struct AtlasLayout: View {
    let figures: MapFigures
    let effects: MapEffects
    let onSelect: (String) -> Void
    let onScan: () -> Void

    enum Segment: String, CaseIterable { case countries, cities, wishlist }
    @State private var segment: Segment = .countries

    var body: some View {
        VStack(spacing: 0) {
            FlatMap(statusByISO: figures.statusByISO, effects: effects, onSelect: onSelect)
                .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    WorldRing(fraction: figures.fraction, percent: figures.percent, size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("^[\(figures.beenTo) country](inflect: true)")
                            .font(.title2.bold()).foregroundStyle(Theme.ink)
                        Text("\(figures.percent)% of the world · ^[\(figures.cityCount) city](inflect: true) · \(figures.wantTo) on wishlist")
                            .font(.subheadline).foregroundStyle(Theme.muted)
                    }
                }
                Picker("Show", selection: $segment) {
                    Text("Countries").tag(Segment.countries)
                    Text("Cities").tag(Segment.cities)
                    Text("Wishlist").tag(Segment.wishlist)
                }
                .pickerStyle(.segmented)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8, pinnedViews: [.sectionHeaders]) {
                        list
                    }
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous)
                    .fill(Theme.canvas)
                    .shadow(color: .black.opacity(0.08), radius: 16, y: -4)
                    .ignoresSafeArea(edges: .bottom))
            .padding(.top, -40)
        }
        .background(Theme.ocean.ignoresSafeArea(edges: .top))
    }

    @ViewBuilder
    private var list: some View {
        switch segment {
        case .countries:
            if figures.atlas.isEmpty {
                MapEmptyHint(onScan: onScan)
            }
            ForEach(figures.atlas) { section in
                Section {
                    VStack(spacing: 0) {
                        ForEach(section.rows) { row in
                            CountryListRow(row: row) { onSelect(row.iso) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .background(Theme.card, in: Theme.cardShape)
                } header: {
                    HStack {
                        Text(section.continent.uppercased())
                        Spacer()
                        Text("\(section.beenTo) of \(section.total)")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .padding(.vertical, 6)
                    .background(Theme.canvas)
                }
            }
        case .cities:
            if figures.cities.isEmpty {
                Text("Cities you add on a country's page show up here.")
                    .font(.subheadline).foregroundStyle(Theme.muted).card()
            } else {
                VStack(spacing: 0) {
                    ForEach(figures.cities) { city in
                        Button { onSelect(city.iso) } label: {
                            HStack(spacing: 12) {
                                Text(city.flag).font(.title3)
                                Text(city.name).foregroundStyle(Theme.ink)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .background(Theme.card, in: Theme.cardShape)
            }
        case .wishlist:
            if figures.wishlist.isEmpty {
                Text("Mark a country as Want to go and it shows up here.")
                    .font(.subheadline).foregroundStyle(Theme.muted).card()
            } else {
                CountryListCard(rows: figures.wishlist, onSelect: onSelect)
            }
        }
    }
}

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
            .toolbar(layout == .globe ? .hidden : .automatic, for: .navigationBar)
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
                GlobeLayout(figures: figures, effects: effects, layout: $layout,
                            onSelect: { router.open($0) }, onScan: { scan() }, onGuide: { showingGuide = true })
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
            LayoutMenu(layout: $layout)
        }
    }

    private func scan() { router.showingImport = true }
}

// MARK: - Globe

/// The layout picker (Globe, Journal, Atlas), as a menu.
struct LayoutMenu: View {
    @Binding var layout: MapLayout

    var body: some View {
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
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
    }
}

/// Immersive Glass: the headline number over the sky, a large globe that
/// bleeds off both edges, floating glass controls, and the details in a sheet
/// that peeks with the four legend tiles.
private struct GlobeLayout: View {
    let figures: MapFigures
    let effects: MapEffects
    @Binding var layout: MapLayout
    let onSelect: (String) -> Void
    let onScan: () -> Void
    let onGuide: () -> Void

    @Environment(\.motionEnabled) private var motionEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Where the globe rests: Europe and Africa in view.
    private static let home = GeoPoint(lon: 15, lat: 30)
    @State private var camera = GlobeCamera(center: GlobeLayout.home)
    @State private var didIntro = false
    @State private var expanded = false

    private var animate: Bool { motionEnabled && !reduceMotion }

    private var isEmpty: Bool { figures.beenTo + figures.wantTo == 0 }
    /// The sheet at rest: the grabber and the legend tiles, or the empty
    /// map's hint with its button, above the tab bar.
    private var collapsedHeight: CGFloat { isEmpty ? 236 : 124 }

    var body: some View {
        GeometryReader { geo in
            // Bleeds off both edges on iPhone; capped by the height on iPad.
            let diameter = min(geo.size.width * 1.25, geo.size.height * 0.82)
            ZStack(alignment: .top) {
                SkyBackdrop(fadeAt: 0.9)

                GlobeMap(statusByISO: figures.statusByISO,
                         center: Binding(get: { camera.center }, set: { camera.set($0) }),
                         effects: effects,
                         showsHalo: true,
                         onSelect: { select($0) },
                         onFling: { target in
                             camera.turn(to: target, duration: 0.9, animated: animate, curve: Motion.easeOutCubic)
                         })
                    .frame(width: diameter, height: diameter)
                    .position(x: geo.size.width / 2, y: 150 + diameter / 2)

                HStack(alignment: .top) {
                    Headline(figures: figures)
                    Spacer(minLength: 12)
                    MapControls(layout: $layout, onScan: onScan, onGuide: onGuide)
                }
                .padding(.horizontal, Theme.margin)
                .padding(.top, 6)

                PullUpPanel(expanded: $expanded, collapsedHeight: collapsedHeight) {
                    VStack(alignment: .leading, spacing: 18) {
                        // An empty map leads with the hint.
                        if isEmpty {
                            MapEmptyHint(onScan: onScan)
                        }
                        LegendTiles(figures: figures)
                        SectionTitle("Continents")
                        ContinentLines(continents: figures.continents)
                        if !isEmpty {
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
                    .padding(.horizontal, Theme.margin)
                    .padding(.bottom, 24)
                }
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

/// "36" set large, then "of 197 countries · 18%".
private struct Headline: View {
    let figures: MapFigures

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(figures.beenTo)")
                .font(.system(size: 76, weight: .heavy).monospacedDigit())
                .tracking(-2)
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText(value: Double(figures.beenTo)))
            Text("of \(figures.total) countries · \(Text("\(figures.percent)%").foregroundStyle(Theme.skyAccent))")
                .font(.title3.weight(.medium))
                .foregroundStyle(Theme.skyInk)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The floating glass capsule: photo scan, layout and how it works.
private struct MapControls: View {
    @Binding var layout: MapLayout
    let onScan: () -> Void
    let onGuide: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onScan) {
                Label("Find countries in my photos", systemImage: "photo.badge.magnifyingglass")
                    .frame(width: 50, height: 48)
                    .contentShape(Rectangle())
            }
            divider
            LayoutMenu(layout: $layout)
            divider
            Button(action: onGuide) {
                Label("How Terris works", systemImage: "questionmark.circle")
                    .frame(width: 50, height: 48)
                    .contentShape(Rectangle())
            }
        }
        .labelStyle(.iconOnly)
        .font(.system(size: 19, weight: .semibold))
        .foregroundStyle(Theme.ink)
        .buttonStyle(.plain)
        .frame(width: 50)
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    private var divider: some View {
        Rectangle().fill(Theme.muted.opacity(0.25)).frame(width: 26, height: 0.5)
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
            // The panel keeps its full height and slides: an offset moves it
            // without laying the lists out again every frame of a drag.
            VStack(spacing: 0) {
                Capsule()
                    .fill(Theme.muted.opacity(0.4))
                    .frame(width: 38, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(Motion.spring) { expanded.toggle() } }
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
            .frame(height: full, alignment: .top)
            .frame(maxWidth: .infinity)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous)
                    .fill(Theme.canvas)
                    .shadow(color: .black.opacity(0.08), radius: 16, y: -4)
                    .ignoresSafeArea(edges: .bottom))
            .offset(y: full - height)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.86), value: drag)
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

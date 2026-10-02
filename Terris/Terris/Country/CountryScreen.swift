//
//  CountryScreen.swift
//  Terris
//
//  A country's page, opened as a sheet from anywhere (map, lists, search).
//  A hero picture (the owner's own photo, or the country's outline), then
//  status, dates, cities, photos, fun facts and notes, all edited inline.
//

import SwiftUI

struct CountryScreen: View {
    @Environment(FootprintStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.motionEnabled) private var motionEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model: CountryModel
    /// The mini globe pulses when the status changes.
    @State private var effects = MapEffects.none
    @State private var notes = ""
    @State private var newCity = ""
    @FocusState private var notesFocused: Bool

    init(iso: String, store: FootprintStore) {
        _model = State(initialValue: CountryModel(iso: iso, store: store))
    }

    var body: some View {
        ScrollView {
            if let f = model.figures {
                VStack(alignment: .leading, spacing: 22) {
                    ZStack(alignment: .bottom) {
                        CountryHero(iso: f.iso, name: f.name, subtitle: subtitle(f), status: f.status,
                                    photoID: model.photoIDs.first, effects: effects)
                        StatusPicker(status: f.status, floating: true) { model.tap($0) }
                            .padding(.horizontal, Theme.margin)
                            .padding(.bottom, 14)
                    }
                    VStack(alignment: .leading, spacing: 22) {
                        if let error = model.error {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .font(.footnote).foregroundStyle(Theme.visited)
                        }
                        if f.showsDates { dates(f) }
                        cities(f)
                        if f.photoCount > 0 { photos(f) }
                        notesCard
                        if !f.facts.isEmpty { facts(f) }
                    }
                    .padding(.horizontal, Theme.margin)
                }
                .padding(.bottom, 32)
            } else {
                ContentUnavailableView("Country not found", systemImage: "globe")
            }
        }
        .scrollIndicators(.hidden)
        // The hero starts inside the safe area (a sheet's top edge sits lower
        // on a real phone than the screen's); the sky colour fills the strip
        // above it so the hero still reads as edge to edge.
        .background {
            VStack(spacing: 0) {
                Theme.skyTop.frame(height: CountryHero.height)
                Theme.canvas
            }
            .ignoresSafeArea()
        }
        .overlay(alignment: .topLeading) {
            GlassIconButton(systemImage: "xmark", label: "Close") { dismiss() }
                .padding(.leading, Theme.margin)
                .padding(.top, 14)
        }
        .task(id: store.version) {
            model.load()
            if !notesFocused { notes = model.figures?.notes ?? "" }
        }
        .onDisappear { model.setNotes(notes) }
        .onChange(of: model.figures?.status) { old, new in
            guard old != nil, old != new, motionEnabled, !reduceMotion else { return }
            effects.pulses = [model.iso: .now]
        }
    }

    // MARK: Sections

    private func subtitle(_ f: CountryFigures) -> Text {
        switch (f.cities.count, f.photoCount) {
        case (0, 0): Text(f.continent)
        case (let c, 0): Text("\(f.continent) · ^[\(c) city](inflect: true)")
        case (0, let p): Text("\(f.continent) · ^[\(p) photo](inflect: true)")
        case (let c, let p): Text("\(f.continent) · ^[\(c) city](inflect: true) · ^[\(p) photo](inflect: true)")
        }
    }

    private func dates(_ f: CountryFigures) -> some View {
        VStack(spacing: 0) {
            OptionalDateRow(title: f.status == .livedIn ? "Moved in" : "First visit",
                            date: f.firstVisit) { model.setFirstVisit($0) }
            Divider().padding(.leading, 40)
            OptionalDateRow(title: f.status == .livedIn ? "Moved out" : "Last visit",
                            date: f.lastVisit) { model.setLastVisit($0) }
        }
        .padding(.horizontal, 16)
        .background(Theme.card, in: Theme.cardShape)
    }

    private func cities(_ f: CountryFigures) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Cities")
            FlowLayout(spacing: 8) {
                ForEach(f.cities, id: \.self) { city in
                    Text(city)
                        .font(.body)
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(Theme.card, in: Capsule())
                        .contextMenu {
                            Button(role: .destructive) { model.removeCity(city) } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                }
            }
            HStack {
                TextField("Add a city", text: $newCity)
                    .submitLabel(.done)
                    .onSubmit(addCity)
                if !newCity.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("Add", action: addCity).bold().tint(Theme.accent)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Theme.card, in: Theme.cardShape)
        }
    }

    private func addCity() {
        model.addCity(newCity)
        newCity = ""
    }

    private func photos(_ f: CountryFigures) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Photos") { Text("\(f.photoCount)").foregroundStyle(Theme.muted) }
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(model.photoIDs, id: \.self) { id in
                        AssetImage(assetIdentifier: id)
                            .frame(width: 104, height: 104)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .padding(.horizontal, Theme.margin)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -Theme.margin)
        }
    }

    private func facts(_ f: CountryFigures) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Did you know?", systemImage: "lightbulb")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.lived)
            ForEach(f.facts, id: \.self) { fact in
                Text(fact)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .padding(.leading, 10)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Theme.lived.opacity(0.35)).frame(width: 3)
                    }
            }
        }
        .card()
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Notes")
            TextField("Memories, tips, who you went with…", text: $notes, axis: .vertical)
                .lineLimit(3...10)
                .focused($notesFocused)
                .onChange(of: notesFocused) { _, focused in
                    if !focused { model.setNotes(notes) }
                }
                .card()
        }
    }
}

// MARK: - Parts

/// Visited / Lived / Want to go. Tapping the selected one clears it.
struct StatusPicker: View {
    let status: TravelStatus
    /// On the country hero: Liquid Glass (a floating control), the selected
    /// option a solid pill.
    var floating = false
    let onTap: (TravelStatus) -> Void

    @Environment(\.colorScheme) private var colorScheme

    /// The selection pill slides from option to option.
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TravelStatus.pickable) { option in
                let selected = option == status
                Button { onTap(option) } label: {
                    Text(option.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(textColor(option, selected: selected))
                        .frame(maxWidth: .infinity, minHeight: floating ? 50 : 44)
                        .background {
                            if selected {
                                Capsule().fill(pillColor(option))
                                    .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityHint(selected ? Text("Tap again to clear") : Text(""))
            }
        }
        .padding(4)
        .background { if !floating { Capsule().fill(Theme.subtle) } }
        .glassEffect(floating ? .regular : .identity, in: Capsule())
        .sensoryFeedback(.selection, trigger: status)
        .animation(Motion.spring, value: status)
    }

    /// Night Atlas fills the selected pill with the status colour; by day
    /// it's a light pill with coloured text.
    private var filledPill: Bool { floating && colorScheme == .dark }

    private func pillColor(_ option: TravelStatus) -> Color {
        filledPill ? Theme.color(for: option) : Theme.card
    }

    private func textColor(_ option: TravelStatus, selected: Bool) -> Color {
        if selected { return filledPill ? Theme.onStatus(option) : Theme.color(for: option) }
        return Theme.ink
    }
}

/// A date that may be unset: "Add" until picked, then a compact picker and a clear button.
struct OptionalDateRow: View {
    let title: LocalizedStringKey
    let date: Date?
    let onChange: (Date?) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar").foregroundStyle(Theme.accent).frame(width: 28)
            Text(title).foregroundStyle(Theme.ink)
            Spacer()
            if let date {
                DatePicker("", selection: Binding(get: { date }, set: { onChange($0) }),
                           in: ...Date.now, displayedComponents: .date)
                    .labelsHidden()
                Button { onChange(nil) } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear date"))
            } else {
                Button("Add") { onChange(.now) }.tint(Theme.accent)
            }
        }
        .frame(minHeight: 52)
    }
}

/// Wraps children onto new lines, like tags.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

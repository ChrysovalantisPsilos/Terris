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
    /// Why some photos can't be shown, by photo, to explain it under the strip.
    @State private var photoProblems: [String: PhotoProblem] = [:]
    @Environment(\.openURL) private var openURL

    init(iso: String, store: FootprintStore) {
        _model = State(initialValue: CountryModel(iso: iso, store: store))
    }

    var body: some View {
        ScrollView {
            if let f = model.figures {
                VStack(alignment: .leading, spacing: 22) {
                    ZStack(alignment: .bottom) {
                        CountryHero(iso: f.iso, name: f.name, subtitle: subtitle(f), status: f.status,
                                    photoIDs: model.photoIDs, effects: effects)
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
        .background(Theme.canvas.ignoresSafeArea())
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
            SectionTitle("Photos") {
                Text("Touch and hold to choose").foregroundStyle(Theme.muted)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(model.photoIDs, id: \.self) { id in
                        photoTile(id, isCover: id == f.cover)
                    }
                }
                .padding(.horizontal, Theme.margin)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -Theme.margin)
            if let problem = worstPhotoProblem {
                photoNote(problem)
            }
        }
    }

    /// A photo: the cover gets a badge; touch and hold to make it the cover
    /// or remove it from this country (the photo stays in your library).
    private func photoTile(_ id: String, isCover: Bool) -> some View {
        AssetImage(assetIdentifier: id, onUnavailable: { photoProblems[id] = $0 })
            .frame(width: 112, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .topLeading) {
                if isCover {
                    Label("Cover", systemImage: "star.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.onPhoto)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Theme.photoScrim, in: Capsule())
                        .padding(8)
                }
            }
            .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contextMenu {
                if photoProblems[id] == nil {
                    Button { model.setCover(id) } label: { Label("Use as cover", systemImage: "star") }
                        .disabled(isCover)
                }
                Button(role: .destructive) {
                    photoProblems[id] = nil
                    model.removePhotos([id])
                } label: {
                    Label("Remove from this country", systemImage: "trash")
                }
            }
            .accessibilityLabel(isCover ? Text("Cover photo") : Text("Photo"))
    }

    /// The reason that matters most: no access, then limited, then missing.
    private var worstPhotoProblem: PhotoProblem? {
        let found = Set(photoProblems.values)
        return [.noAccess, .notShared, .missing, .couldNotLoad].first { found.contains($0) }
    }

    @ViewBuilder
    private func photoNote(_ problem: PhotoProblem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch problem {
            case .noAccess:
                Text("Terris can't see your photos").font(.headline)
                Text("Allow access in Settings to show them here. They stay on your iPhone.")
                    .font(.subheadline).foregroundStyle(Theme.muted)
                settingsButton
            case .notShared:
                Text("Terris can only see the photos you've shared with it").font(.headline)
                Text("Choose Full Access in Settings to show these. They stay on your iPhone.")
                    .font(.subheadline).foregroundStyle(Theme.muted)
                settingsButton
            case .missing:
                Text("Some photos aren't on this iPhone").font(.headline)
                Text("They were deleted, or found on a device that isn't sharing them through iCloud Photos.")
                    .font(.subheadline).foregroundStyle(Theme.muted)
                Button(role: .destructive) {
                    let gone = photoProblems.filter { $0.value == .missing }.map(\.key)
                    for id in gone { photoProblems[id] = nil }
                    model.removePhotos(gone)
                } label: {
                    Label("Remove them", systemImage: "trash").font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            case .couldNotLoad:
                Text("Some photos couldn't be loaded").font(.headline)
                Text("They're kept in iCloud Photos and didn't download just now. Check your connection and open this page again.")
                    .font(.subheadline).foregroundStyle(Theme.muted)
            }
        }
        .foregroundStyle(Theme.ink)
        .card()
    }

    private var settingsButton: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        } label: {
            Label("Open Settings", systemImage: "gear").font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.accent)
        .padding(.top, 4)
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
        let rows = Self.rows(subviews.map { $0.sizeThatFits(.unspecified) }, width: proposal.width ?? .infinity, spacing: spacing)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        // Wrap against the same width sizeThatFits used, so the rows placed
        // are exactly the rows measured.
        let rows = Self.rows(sizes, width: proposal.width ?? bounds.width, spacing: spacing)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sizes[index]))
                x += sizes[index].width + spacing
            }
            y += row.height + spacing
        }
    }

    /// Items packed into rows no wider than `width`.
    static func rows(_ sizes: [CGSize], width: CGFloat, spacing: CGFloat) -> [(indices: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(indices: [Int], width: CGFloat, height: CGFloat)] = []
        for (i, size) in sizes.enumerated() {
            if let last = rows.last, !last.indices.isEmpty, last.width + spacing + size.width <= width + 0.5 {
                rows[rows.count - 1] = (last.indices + [i], last.width + spacing + size.width, max(last.height, size.height))
            } else {
                rows.append(([i], size.width, size.height))
            }
        }
        return rows
    }
}

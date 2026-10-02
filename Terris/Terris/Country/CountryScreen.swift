//
//  CountryScreen.swift
//  Terris
//
//  A country's page, opened as a sheet from anywhere (map, lists, search).
//  Status, dates, cities, photos, fun facts and notes, all edited inline.
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
        NavigationStack {
            ScrollView {
                if let f = model.figures {
                    VStack(alignment: .leading, spacing: 20) {
                        header(f)
                        StatusPicker(status: f.status) { model.tap($0) }
                        if let error = model.error {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .font(.footnote).foregroundStyle(Theme.visited)
                        }
                        if f.showsDates { dates(f) }
                        cities(f)
                        if f.photoCount > 0 { photos(f) }
                        if !f.facts.isEmpty { facts(f) }
                        notesCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                } else {
                    ContentUnavailableView("Country not found", systemImage: "globe")
                }
            }
            .background(Theme.canvas.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Label("Close", systemImage: "xmark") }
                }
            }
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

    private func header(_ f: CountryFigures) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(f.flag).font(.system(size: 44))
                Text(f.name).font(.largeTitle.bold()).foregroundStyle(Theme.ink)
                    .lineLimit(2).minimumScaleFactor(0.7)
                Text(subtitle(f)).font(.subheadline).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
            if let centroid = WorldShapes.shared.centroid(of: f.iso) {
                GlobeMap(statusByISO: [f.iso: f.status == .none ? .visited : f.status],
                         center: .constant(centroid), highlightISO: f.iso, interactive: false,
                         effects: effects)
                    .frame(width: 112, height: 112)
                    .accessibilityHidden(true)
            }
        }
        .padding(.top, 4)
    }

    private func subtitle(_ f: CountryFigures) -> String {
        var parts = [f.continent]
        if !f.cities.isEmpty { parts.append(f.cities.count == 1 ? "1 city" : "\(f.cities.count) cities") }
        if f.photoCount > 0 { parts.append(f.photoCount == 1 ? "1 photo" : "\(f.photoCount) photos") }
        return parts.joined(separator: " · ")
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
                    Label(city, systemImage: "mappin")
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12).padding(.vertical, 8)
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
            SectionTitle("Photos") { Text("\(f.photoCount)") }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                ForEach(model.photoIDs, id: \.self) { id in
                    AssetImage(assetIdentifier: id)
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
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
    let onTap: (TravelStatus) -> Void

    /// The selection pill slides from option to option.
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TravelStatus.pickable) { option in
                let selected = option == status
                Button { onTap(option) } label: {
                    Text(option.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selected ? Theme.color(for: option) : Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            if selected {
                                Capsule().fill(Theme.card)
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
        .background(Theme.subtle, in: Capsule())
        .sensoryFeedback(.selection, trigger: status)
        .animation(Motion.spring, value: status)
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

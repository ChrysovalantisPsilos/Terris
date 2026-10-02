//
//  FlightFormScreen.swift
//  Terris
//
//  Log a flight, or edit one. Airports are picked inline in the route card
//  (no search sheet); the distance updates as you pick.
//

import SwiftUI

@MainActor
@Observable
final class FlightFormModel {
    var draft: FlightDraft
    private(set) var error: String?
    let isEditing: Bool
    private let store: FootprintStore

    init(draft: FlightDraft, store: FootprintStore) {
        self.draft = draft
        self.isEditing = draft.id != nil
        self.store = store
    }

    /// Saves; returns true when done.
    func save() -> Bool {
        let ok = store.saveFlight(draft)
        error = ok ? nil : store.lastError
        return ok
    }
}

struct FlightFormScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: FlightFormModel
    @State private var picking: Side?
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    enum Side { case from, to }

    init(draft: FlightDraft, store: FootprintStore) {
        _model = State(initialValue: FlightFormModel(draft: draft, store: store))
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    routeCard
                } footer: {
                    if let text = problemText { text.foregroundStyle(Theme.muted) }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section("When") {
                    DatePicker("Departure", selection: $model.draft.departure)
                    if let arrival = model.draft.arrival {
                        DatePicker("Arrival", selection: Binding(get: { arrival }, set: { model.draft.arrival = $0 }),
                                   in: model.draft.departure...)
                        if let minutes = model.draft.minutes {
                            LabeledContent("Flight time") { DurationText(minutes: minutes) }
                        }
                        Button("Remove arrival time", role: .destructive) { model.draft.arrival = nil }
                    } else {
                        Button("Add arrival time") {
                            model.draft.arrival = model.draft.departure.addingTimeInterval(2 * 3600)
                        }
                    }
                }

                Section("Flight") {
                    TextField("Airline", text: $model.draft.airline)
                        .textInputAutocapitalization(.words)
                    TextField("Flight number, e.g. A3 621", text: $model.draft.number)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }

                Section("Seat") {
                    Picker("Class", selection: $model.draft.seatClass) {
                        ForEach(SeatClass.allCases) { Text($0.label).tag($0) }
                    }
                    TextField("Seat, e.g. 12A", text: $model.draft.seat)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }

                Section("Rating") {
                    RatingPicker(rating: $model.draft.rating)
                }

                Section("Notes") {
                    TextField("Delays, views, who you sat next to…", text: $model.draft.notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                if let error = model.error {
                    Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(Theme.visited) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.canvas.ignoresSafeArea())
            .tint(Theme.accent)
            .navigationTitle(model.isEditing ? Text("Edit flight") : Text("Log a flight"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { if model.save() { dismiss() } }
                        .bold()
                        .disabled(!model.draft.canSave)
                }
            }
            .sensoryFeedback(.selection, trigger: model.draft.from?.iata)
            .sensoryFeedback(.selection, trigger: model.draft.to?.iata)
        }
    }

    // MARK: Route card

    private var routeCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 8) {
                endpoint(.from, airport: model.draft.from)
                Button {
                    withAnimation(Theme.spring) { model.draft.swapAirports() }
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 44, height: 44)
                        .background(Theme.subtle, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.top, 18)
                .accessibilityLabel(Text("Swap airports"))
                endpoint(.to, airport: model.draft.to)
            }

            if let km = model.draft.distanceKm {
                Label {
                    Text("\(km, format: .number.precision(.fractionLength(0))) km")
                } icon: {
                    Image(systemName: "airplane")
                }
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.muted)
                .contentTransition(.numericText(value: km))
            }

            if let picking {
                airportSearch(for: picking)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(Theme.card, in: Theme.cardShape)
        .animation(Theme.spring, value: picking)
    }

    private func endpoint(_ side: Side, airport: AirportRecord?) -> some View {
        let active = picking == side
        return Button {
            query = ""
            picking = active ? nil : side
            searchFocused = picking != nil
        } label: {
            VStack(alignment: side == .from ? .leading : .trailing, spacing: 2) {
                Text(side == .from ? "From" : "To")
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                Text(airport?.iata ?? "———")
                    .font(.system(size: 34, weight: .bold).monospaced())
                    .foregroundStyle(airport == nil ? Theme.muted : Theme.ink)
                (airport.map { Text($0.city) } ?? Text("Pick an airport"))
                    .font(.subheadline).foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: side == .from ? .leading : .trailing)
            .padding(10)
            .background(active ? Theme.accent.opacity(0.10) : .clear,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(side == .from ? Text("From airport") : Text("To airport"))
        .accessibilityValue(Text(airport.map { "\($0.iata), \($0.city)" } ?? ""))
    }

    private func airportSearch(for side: Side) -> some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                TextField("Airport, city or code", text: $query)
                    .focused($searchFocused)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                Button("Done") { picking = nil }
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Theme.subtle, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            ForEach(AirportSearch.filter(kAirportDatabase, query: query)) { airport in
                Button { pick(airport, for: side) } label: {
                    HStack(spacing: 12) {
                        Text(airport.iata)
                            .font(.subheadline.weight(.bold).monospaced())
                            .foregroundStyle(Theme.ink)
                            .frame(width: 48, height: 32)
                            .background(Theme.subtle, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(Flag.emoji(for: airport.countryISO)) \(airport.city)")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                            Text(airport.name).font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pick(_ airport: AirportRecord, for side: Side) {
        switch side {
        case .from: model.draft.from = airport
        case .to: model.draft.to = airport
        }
        query = ""
        // Move on to the other end if it's still empty.
        if side == .from, model.draft.to == nil {
            picking = .to
        } else {
            picking = nil
            searchFocused = false
        }
    }

    private var problemText: Text? {
        switch model.draft.problem {
        case .missingRoute: Text("Pick where you flew from and to.")
        case .sameAirport: Text("From and to are the same airport.")
        case .arrivesBeforeDeparture: Text("Arrival is before departure.")
        case nil: nil
        }
    }
}

// MARK: - Parts

/// "2h 35m".
struct DurationText: View {
    let minutes: Int
    var body: some View {
        Text(Duration.seconds(minutes * 60), format: .units(allowed: [.hours, .minutes], width: .narrow))
    }
}

/// Five stars; tapping the current rating clears it.
struct RatingPicker: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { i in
                Button {
                    rating = rating == i ? 0 : i
                } label: {
                    Image(systemName: i <= rating ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundStyle(i <= rating ? Theme.wantTo : Theme.muted)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .sensoryFeedback(.selection, trigger: rating)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Rating"))
        .accessibilityValue(Text("\(rating) of 5"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: rating = min(rating + 1, 5)
            case .decrement: rating = max(rating - 1, 0)
            @unknown default: break
            }
        }
    }
}

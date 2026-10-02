//
//  FlightScreen.swift
//  Terris
//
//  One flight: the route, its arc on your map, and the details. Edit opens
//  the same form as logging; delete asks first.
//

import SwiftUI

@MainActor
@Observable
final class FlightModel {
    let id: UUID
    private(set) var flight: FlightRecord?
    private(set) var statusByISO: [String: TravelStatus] = [:]
    private let store: FootprintStore

    init(id: UUID, store: FootprintStore) {
        self.id = id
        self.store = store
    }

    func load() {
        flight = store.flightRecord(id: id)
        statusByISO = Dictionary(store.countryRecords().filter { $0.status != .none }.map { ($0.iso, $0.status) },
                                 uniquingKeysWith: { a, _ in a })
    }

    func draft() -> FlightDraft? { store.flightDraft(id: id) }
    func delete() { store.deleteFlight(id: id) }
}

struct FlightScreen: View {
    @Environment(FootprintStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var model: FlightModel
    @State private var editing: FlightDraft?
    @State private var confirmingDelete = false

    init(id: UUID, store: FootprintStore) {
        _model = State(initialValue: FlightModel(id: id, store: store))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let f = model.flight {
                    VStack(alignment: .leading, spacing: 18) {
                        routeCard(f)
                        details(f)
                        if let notes = f.notes {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionTitle("Notes")
                                Text(notes).foregroundStyle(Theme.ink).card()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                } else {
                    ContentUnavailableView("Flight not found", systemImage: "airplane")
                }
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle(model.flight?.number.map { Text($0) } ?? Text("Flight"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Label("Close", systemImage: "xmark") }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Edit") { editing = model.draft() }
                    Button(role: .destructive) { confirmingDelete = true } label: {
                        Label("Delete flight", systemImage: "trash")
                    }
                }
            }
            .confirmationDialog("Delete this flight?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete flight", role: .destructive) {
                    model.delete()
                    dismiss()
                }
            } message: {
                Text("It's removed from your log on all your devices.")
            }
            .sheet(item: $editing) { draft in
                FlightFormScreen(draft: draft, store: store)
            }
        }
        .task(id: store.version) { model.load() }
    }

    // MARK: Route

    private func routeCard(_ f: FlightRecord) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                end(f.from, city: f.fromCity, time: f.date, alignment: .leading)
                Spacer(minLength: 8)
                VStack(spacing: 4) {
                    Image(systemName: "airplane")
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                    if let minutes = f.minutes {
                        DurationText(minutes: minutes)
                            .font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                    }
                }
                .padding(.top, 14)
                Spacer(minLength: 8)
                end(f.to, city: f.toCity, time: f.arrival, alignment: .trailing)
            }
            if let route = Self.route(f) {
                FlatMap(statusByISO: model.statusByISO, routes: [route])
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .card()
    }

    private func end(_ code: String, city: String?, time: Date?, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(code.isEmpty ? "—" : code)
                .font(.system(size: 38, weight: .bold).monospaced())
                .foregroundStyle(Theme.ink)
            if let city { Text(city).font(.subheadline).foregroundStyle(Theme.muted).lineLimit(1) }
            if let time {
                Text(time, format: .dateTime.hour().minute())
                    .font(.caption.monospacedDigit()).foregroundStyle(Theme.muted)
            }
        }
    }

    private static func route(_ f: FlightRecord) -> FlightFigures.Route? {
        guard let a = f.fromPoint, let b = f.toPoint else { return nil }
        return FlightFigures.Route(from: a, to: b)
    }

    // MARK: Details

    private func details(_ f: FlightRecord) -> some View {
        VStack(spacing: 0) {
            if let date = f.date {
                row("calendar", "Date") { Text(date, format: .dateTime.weekday(.wide).day().month(.wide).year()) }
            }
            if f.km > 0 {
                row("point.topleft.down.to.point.bottomright.curvepath", "Distance") {
                    Text("\(f.km, format: .number.precision(.fractionLength(0))) km")
                }
            }
            if let minutes = f.minutes {
                row("clock", "Flight time") { DurationText(minutes: minutes) }
            }
            if let airline = f.airline { row("building.2", "Airline") { Text(airline) } }
            if let number = f.number { row("number", "Flight number") { Text(number) } }
            if let seatClass = f.seatClass { row("carseat.right", "Class") { Text(seatClass.label) } }
            if let seat = f.seat { row("chair", "Seat") { Text(seat) } }
            if f.rating > 0 {
                row("star", "Rating") {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: i <= f.rating ? "star.fill" : "star")
                                .foregroundStyle(i <= f.rating ? Theme.wantTo : Theme.muted)
                        }
                    }
                    .font(.caption)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("\(f.rating) of 5"))
                }
            }
        }
        .padding(.horizontal, 16)
        .background(Theme.card, in: Theme.cardShape)
    }

    private func row<Value: View>(_ icon: String, _ title: LocalizedStringKey,
                                  @ViewBuilder value: () -> Value) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.accent).frame(width: 24)
            Text(title).foregroundStyle(Theme.ink)
            Spacer()
            value().foregroundStyle(Theme.muted)
        }
        .frame(minHeight: 48)
        .accessibilityElement(children: .combine)
    }
}

/// For `.sheet(item:)` when editing; an edited draft always has its flight's id.
extension FlightDraft: Identifiable {}

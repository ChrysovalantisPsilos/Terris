//
//  FlightsScreen.swift
//  Terris
//
//  The Flights tab: totals, a route map, and the log grouped by year.
//  Adding and the flight detail still use the existing forms.
//

import SwiftUI

@MainActor
@Observable
final class FlightsModel {
    private(set) var figures = FlightFigures.compute([])
    private(set) var statusByISO: [String: TravelStatus] = [:]
    private let store: FootprintStore

    init(store: FootprintStore) { self.store = store }

    func load() {
        figures = FlightFigures.compute(store.flightRecords())
        statusByISO = Dictionary(store.countryRecords().filter { $0.status != .none }.map { ($0.iso, $0.status) },
                                 uniquingKeysWith: { a, _ in a })
    }

    func delete(_ id: UUID) { store.deleteFlight(id: id); load() }
    func flight(_ id: UUID) -> Flight? { store.flight(id: id) }
}

private struct OpenFlight: Identifiable {
    let id: UUID
}

struct FlightsScreen: View {
    @Environment(FootprintStore.self) private var store
    @State private var model: FlightsModel?
    @State private var adding = false
    @State private var open: OpenFlight?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let model {
                    content(model)
                }
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle("Flights")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { adding = true } label: { Label("Add flight", systemImage: "plus") }
                }
            }
        }
        .task(id: store.version) {
            if model == nil { model = FlightsModel(store: store) }
            withAnimation(Theme.spring) { model?.load() }
        }
        .sheet(isPresented: $adding) { AddFlightView() }
        .sheet(item: $open) { item in
            if let flight = model?.flight(item.id) {
                NavigationStack { FlightDetailView(flight: flight) }
            }
        }
    }

    @ViewBuilder
    private func content(_ model: FlightsModel) -> some View {
        let f = model.figures
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    total(Text("\(f.count)"), f.count == 1 ? Text("flight") : Text("flights"))
                    Spacer()
                    total(Text(f.km, format: .number.precision(.fractionLength(0))), Text("km flown"))
                    Spacer()
                    total(Text("\(f.airports)"), f.airports == 1 ? Text("airport") : Text("airports"))
                }
                FlatMap(statusByISO: model.statusByISO, routes: f.routes)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                if f.km > 0 {
                    Text("That's \(f.timesAroundEarth, format: .number.precision(.fractionLength(1)))× around the Earth.")
                        .font(.footnote).foregroundStyle(Theme.muted)
                }
            }
            .card()

            if f.sections.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("No flights yet").font(.headline).foregroundStyle(Theme.ink)
                    Text("Log a flight to see your routes, distance and airports.")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                    Button { adding = true } label: {
                        Label("Log your first flight", systemImage: "plus").font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                }
                .card()
            }

            ForEach(f.sections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        if let year = section.year {
                            Text(String(year))
                        } else {
                            Text("No date")
                        }
                        Spacer()
                        Text("^[\(section.rows.count) flight](inflect: true)")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                            FlightRow(row: row)
                                .contentShape(Rectangle())
                                .onTapGesture { open = OpenFlight(id: row.id) }
                                .contextMenu {
                                    Button(role: .destructive) { model.delete(row.id) } label: {
                                        Label("Delete flight", systemImage: "trash")
                                    }
                                }
                            if index < section.rows.count - 1 { Divider().padding(.leading, 56) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .background(Theme.card, in: Theme.cardShape)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    private func total(_ value: Text, _ label: Text) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            value.font(.title2.bold().monospacedDigit()).foregroundStyle(Theme.ink)
            label.font(.caption).foregroundStyle(Theme.muted)
        }
    }
}

private struct FlightRow: View {
    let row: FlightRecord

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 0) {
                if let date = row.date {
                    Text(date, format: .dateTime.day()).font(.headline).foregroundStyle(Theme.ink)
                    Text(date, format: .dateTime.month(.abbreviated)).font(.caption2.weight(.semibold))
                        .textCase(.uppercase).foregroundStyle(Theme.muted)
                }
            }
            .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.from).font(.headline)
                    Image(systemName: "airplane").font(.caption).foregroundStyle(Theme.accent)
                    Text(row.to).font(.headline)
                }
                .foregroundStyle(Theme.ink)
                if let line = [row.airline, row.number].compactMap({ $0 }).joined(separator: " · ").nilIfEmpty {
                    Text(line).font(.caption).foregroundStyle(Theme.muted)
                }
            }
            Spacer()
            if row.km > 0 {
                Text("\(row.km, format: .number.precision(.fractionLength(0))) km")
                    .font(.subheadline.monospacedDigit()).foregroundStyle(Theme.muted)
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

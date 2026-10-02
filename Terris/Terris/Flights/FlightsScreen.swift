//
//  FlightsScreen.swift
//  Terris
//
//  The Flights tab: the route map edge to edge, the distance flown set
//  large, how far around the Earth that is, and the log grouped by year.
//  Logging opens FlightFormScreen; a row opens FlightScreen.
//

import SwiftUI

@MainActor
@Observable
final class FlightsModel {
    private(set) var figures = FlightFigures.compute([])
    private let store: FootprintStore

    init(store: FootprintStore) { self.store = store }

    func load() {
        figures = FlightFigures.compute(store.flightRecords())
    }

    func delete(_ id: UUID) { store.deleteFlight(id: id); load() }
}

private struct OpenFlight: Identifiable {
    let id: UUID
}

struct FlightsScreen: View {
    @Environment(FootprintStore.self) private var store
    @State private var model: FlightsModel?
    @State private var adding = false
    @State private var open: OpenFlight?
    @Environment(\.motionEnabled) private var motionEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Routes draw themselves the first time the tab shows.
    @State private var effects = MapEffects.none
    @State private var drewRoutes = false

    var body: some View {
        ScrollView {
            if let model {
                content(model)
            }
        }
        .scrollIndicators(.hidden)
        .background(Theme.canvas.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            GlassIconButton(systemImage: "plus", label: "Add flight") { adding = true }
                .padding(.trailing, Theme.margin)
                .padding(.top, 6)
        }
        .task(id: store.version) {
            if model == nil { model = FlightsModel(store: store) }
            withAnimation(Theme.spring) { model?.load() }
        }
        .sheet(isPresented: $adding) {
            FlightFormScreen(draft: .new(now: .now), store: store)
        }
        .sheet(item: $open) { item in
            FlightScreen(id: item.id, store: store)
        }
    }

    @ViewBuilder
    private func content(_ model: FlightsModel) -> some View {
        let f = model.figures
        VStack(alignment: .leading, spacing: 0) {
            Text("Flights")
                .font(.system(size: 40, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, Theme.margin)
                .padding(.top, 52)
                .accessibilityAddTraits(.isHeader)

            // The routes, edge to edge, fading into the page above and below.
            // Land stays neutral: the routes are the only colour here.
            FlatMap(statusByISO: [:], routes: f.routes, effects: effects, showsOcean: false)
                .overlay {
                    LinearGradient(stops: [
                        .init(color: Theme.canvas, location: 0),
                        .init(color: Theme.canvas.opacity(0), location: 0.14),
                        .init(color: Theme.canvas.opacity(0), location: 0.82),
                        .init(color: Theme.canvas, location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false)
                }
                .onAppear {
                    guard !drewRoutes, !f.routes.isEmpty else { return }
                    drewRoutes = true
                    if motionEnabled && !reduceMotion { effects.routeStart = .now }
                }

            VStack(alignment: .leading, spacing: 22) {
                if f.count > 0 {
                    totals(f)
                } else {
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
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Group {
                                if let year = section.year {
                                    Text(String(year))
                                } else {
                                    Text("No date")
                                }
                            }
                            .font(.title2.bold())
                            .foregroundStyle(Theme.ink)
                            Spacer()
                            Text("^[\(section.rows.count) flight](inflect: true)")
                                .font(.subheadline).foregroundStyle(Theme.muted)
                        }
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
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, 24)
        }
    }

    /// "19,200 km", then the share of a lap around the Earth, then counts.
    private func totals(_ f: FlightFigures) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(f.km, format: .number.precision(.fractionLength(0)))
                    .font(.system(size: 64, weight: .heavy).monospacedDigit())
                    .tracking(-1.5)
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("km").font(.title.weight(.semibold)).foregroundStyle(Theme.muted)
            }
            HStack(alignment: .firstTextBaseline) {
                Text("\(f.timesAroundEarth, format: .number.precision(.fractionLength(2)))× around the Earth")
                    .font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
                Spacer()
                Text("\(f.nextLap)×")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.muted)
            }
            ProgressBar(fraction: f.lapFraction)
            Text("^[\(f.count) flight](inflect: true) · ^[\(f.airports) airport](inflect: true)")
                .font(.headline.weight(.regular)).foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .combine)
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

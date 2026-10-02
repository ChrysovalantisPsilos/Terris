//
//  MapComponents.swift
//  Terris
//
//  Pieces shared by the three Map layouts (Globe, Journal, Atlas).
//

import SwiftUI

/// The share-of-the-world ring with the percent inside.
struct WorldRing: View {
    let fraction: Double
    let percent: Int
    var size: CGFloat = 56
    var lineWidth: CGFloat = 6

    @Environment(\.motionEnabled) private var motionEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    var body: some View {
        let animate = motionEnabled && !reduceMotion
        // Sweeps up from empty the first time it shows.
        let shown = grown || !animate ? fraction : 0
        ZStack {
            Circle().stroke(Theme.subtle, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(shown, 0.005))
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(percent)%")
                .font(.system(size: size * 0.24, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText(value: Double(percent)))
        }
        .frame(width: size, height: size)
        .animation(Theme.spring, value: fraction)
        .onAppear {
            guard animate, !grown else { return }
            withAnimation(Motion.gentle.delay(0.15)) { grown = true }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("\(percent) percent of the world"))
    }
}

/// "34 visited · 2 lived · 8 want to go" with colour keys.
struct StatusLegend: View {
    let figures: MapFigures

    var body: some View {
        HStack(spacing: 12) {
            key(color: Theme.visited, hatched: false, text: Text("\(figures.visited) visited"))
            key(color: Theme.lived, hatched: false, text: Text("\(figures.lived) lived"))
            key(color: Theme.wantTo, hatched: true, text: Text("\(figures.wantTo) want to go"))
        }
        .font(.footnote)
        .foregroundStyle(Theme.muted)
    }

    private func key(color: Color, hatched: Bool, text: Text) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3)
                .fill(hatched ? Theme.wantToFill : color)
                .overlay {
                    if hatched {
                        RoundedRectangle(cornerRadius: 3).strokeBorder(color, lineWidth: 1.5)
                    }
                }
                .frame(width: 11, height: 11)
            text
        }
    }
}

/// The four tiles the Globe layout's sheet peeks with: visited, lived,
/// want to go, cities.
struct LegendTiles: View {
    let figures: MapFigures

    var body: some View {
        HStack(spacing: 10) {
            tile(figures.visited, Text("Visited")) { swatch(Theme.visited) }
            tile(figures.lived, Text("Lived")) { swatch(Theme.lived) }
            tile(figures.wantTo, Text("Want to go")) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.wantToFill)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.wantTo, lineWidth: 1.5))
                    .frame(width: 12, height: 12)
            }
            tile(figures.cityCount, Text("Cities")) {
                Image(systemName: "mappin").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            }
        }
    }

    private func swatch(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
    }

    private func tile(_ value: Int, _ label: Text, @ViewBuilder key: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top) {
                Text("\(value)")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText(value: Double(value)))
                Spacer(minLength: 2)
                key().padding(.top, 6)
            }
            label.font(.subheadline).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.subtle, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Continents as slim one-line rows: name, bar, count (Globe layout).
struct ContinentLines: View {
    let continents: [ContinentFigure]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(continents.enumerated()), id: \.element.id) { index, c in
                HStack(spacing: 12) {
                    Text(c.name).foregroundStyle(Theme.ink)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(width: 128, alignment: .leading)
                    ProgressBar(fraction: c.fraction)
                    Text("\(Text("\(c.beenTo)").bold().foregroundStyle(Theme.ink)) / \(c.total)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Theme.muted)
                        .frame(minWidth: 52, alignment: .trailing)
                }
                .padding(.vertical, 11)
                .accessibilityElement(children: .combine)
                .reveal(index)
                if index < continents.count - 1 { Divider() }
            }
        }
        .card(padding: 16)
    }
}

/// Continent rows with a bar each (Journal layout).
struct ContinentRows: View {
    let continents: [ContinentFigure]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(continents.enumerated()), id: \.element.id) { index, c in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(c.name).foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(Text("\(c.beenTo)").bold().foregroundStyle(Theme.ink)) of \(c.total)")
                            .foregroundStyle(Theme.muted)
                    }
                    ProgressBar(fraction: c.fraction)
                }
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
                .reveal(index)
                if index < continents.count - 1 { Divider() }
            }
        }
        .card(padding: 16)
    }
}

struct ProgressBar: View {
    let fraction: Double

    @Environment(\.motionEnabled) private var motionEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    var body: some View {
        let animate = motionEnabled && !reduceMotion
        // Grows in from the left the first time it shows.
        let shown = grown || !animate ? fraction : 0
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.subtle)
                Capsule().fill(Theme.accent)
                    .frame(width: max(geo.size.width * shown, shown > 0 ? 6 : 0))
            }
        }
        .frame(height: 6)
        .animation(Theme.spring, value: fraction)
        .onAppear {
            guard animate, !grown else { return }
            withAnimation(Motion.gentle.delay(0.2)) { grown = true }
        }
    }
}

/// A tappable country row: flag, name, a subtitle and the status badge.
struct CountryListRow: View {
    let row: CountryRow
    var subtitle: Text? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(row.flag).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.name).foregroundStyle(Theme.ink)
                    if let subtitle { subtitle.font(.caption).foregroundStyle(Theme.muted) }
                }
                Spacer()
                StatusBadge(status: row.status)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct StatusBadge: View {
    let status: TravelStatus

    var body: some View {
        Text(status.label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status == .wantToVisit ? Theme.ink : Theme.color(for: status))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Theme.color(for: status).opacity(status == .wantToVisit ? 0.35 : 0.14),
                        in: Capsule())
    }
}

/// "Recently added" and "Want to go" lists.
struct CountryListCard: View {
    let rows: [CountryRow]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                CountryListRow(row: row, subtitle: Self.subtitle(row)) { onSelect(row.iso) }
                    .reveal(index)
                if index < rows.count - 1 { Divider().padding(.leading, 44) }
            }
        }
        .padding(.horizontal, 16)
        .background(Theme.card, in: Theme.cardShape)
    }

    private static func subtitle(_ row: CountryRow) -> Text {
        if row.cityCount > 0, let date = row.date {
            return Text("^[\(row.cityCount) city](inflect: true) · \(date.formatted(.dateTime.month(.abbreviated).year()))")
        }
        if let date = row.date { return Text(date.formatted(.dateTime.month(.abbreviated).year())) }
        return Text(row.continent)
    }
}

/// What every layout shows when nothing is marked yet.
struct MapEmptyHint: View {
    let onScan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your map is empty").font(.headline).foregroundStyle(Theme.ink)
            Text("Tap a country to mark it, or let Terris find the countries in your photos.")
                .font(.subheadline).foregroundStyle(Theme.muted)
            Button(action: onScan) {
                Label("Find countries in my photos", systemImage: "photo.on.rectangle.angled")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .card()
    }
}

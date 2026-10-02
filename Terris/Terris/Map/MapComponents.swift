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

    var body: some View {
        ZStack {
            Circle().stroke(Theme.subtle, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(fraction, 0.005))
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(percent)%")
                .font(.system(size: size * 0.24, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.ink)
        }
        .frame(width: size, height: size)
        .animation(Theme.spring, value: fraction)
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

/// The headline: count, share of the world and cities.
struct HeadlineText: View {
    let figures: MapFigures
    var large = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("^[\(figures.beenTo) country](inflect: true)")
                .font(large ? .largeTitle.bold() : .title2.bold())
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText(value: Double(figures.beenTo)))
            Text("of \(figures.total) · ^[\(figures.cityCount) city](inflect: true)")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
    }
}

/// Six continent tiles in a 3×2 grid (Globe layout).
struct ContinentGrid: View {
    let continents: [ContinentFigure]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(continents) { c in
                VStack(alignment: .leading, spacing: 6) {
                    Text(c.name).font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("\(Text("\(c.beenTo)").font(.title3.bold()).foregroundStyle(Theme.ink)) / \(c.total)")
                        .font(.footnote).foregroundStyle(Theme.muted)
                    ProgressBar(fraction: c.fraction)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.subtle, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityElement(children: .combine)
            }
        }
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
                if index < continents.count - 1 { Divider() }
            }
        }
        .card(padding: 16)
    }
}

struct ProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.subtle)
                Capsule().fill(Theme.accent)
                    .frame(width: max(geo.size.width * fraction, fraction > 0 ? 6 : 0))
            }
        }
        .frame(height: 6)
        .animation(Theme.spring, value: fraction)
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

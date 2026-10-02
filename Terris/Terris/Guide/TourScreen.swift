//
//  TourScreen.swift
//  Terris
//
//  A five-card tour of how Terris works, shown once (after the first-launch
//  scan, or on first open for people who already have countries) and again
//  from "How Terris works". Each card has a small live illustration built
//  from the app's own parts; the illustrations hold still with Reduce Motion.
//

import SwiftUI

/// The tour's cards, in order.
enum TourCard: Int, CaseIterable, Identifiable {
    case globe, mark, photos, flights, layouts

    var id: Int { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .globe: "Your world, shaded"
        case .mark: "Tap a country"
        case .photos: "Found in your photos"
        case .flights: "Log your flights"
        case .layouts: "Three ways to look"
        }
    }

    var text: LocalizedStringKey {
        switch self {
        case .globe:
            "Every country you've been to fills in on the globe. The number at the top is how much of the world you've seen."
        case .mark:
            "Mark a country Visited, Lived or Want to go. Tap the same one again to clear it. Add cities, dates and notes on its page."
        case .photos:
            "Terris can read where your photos were taken and fill in the countries for you. It all happens on your iPhone; your photos never leave it."
        case .flights:
            "Add your flights to see your routes, the distance you've flown and how many times that is around the Earth."
        case .layouts:
            "Switch between Globe, Journal and Atlas with the layers button, and find any country from Search."
        }
    }
}

/// Sample marks for the illustrations (not the user's data).
private let sampleStatuses: [String: TravelStatus] = [
    "FR": .visited, "IT": .visited, "ES": .visited, "PT": .visited, "GR": .livedIn,
    "EG": .visited, "MA": .visited, "TR": .visited, "GB": .visited, "BR": .wantToVisit,
]

struct TourScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0
    /// Called when the tour closes (finished or skipped).
    private let onFinish: () -> Void

    init(startingAt card: TourCard = .globe, onFinish: @escaping () -> Void = {}) {
        _page = State(initialValue: card.rawValue)
        self.onFinish = onFinish
    }

    private var isLast: Bool { page == TourCard.allCases.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if !isLast {
                    Button("Skip") { finish() }
                        .font(.subheadline.weight(.semibold))
                        .tint(Theme.muted)
                        .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 52)

            TabView(selection: $page) {
                ForEach(TourCard.allCases) { card in
                    TourCardView(card: card, isCurrent: page == card.rawValue)
                        .tag(card.rawValue)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            PageDots(count: TourCard.allCases.count, current: page)
                .padding(.bottom, 20)

            Button {
                if isLast { finish() } else { withAnimation(Motion.spring) { page += 1 } }
            } label: {
                Text(isLast ? "Start exploring" : "Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .contentTransition(.opacity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Theme.accent)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(Theme.canvas.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: page)
    }

    private func finish() {
        onFinish()
        dismiss()
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Theme.accent : Theme.muted.opacity(0.35))
                    .frame(width: i == current ? 20 : 7, height: 7)
            }
        }
        .animation(Motion.spring, value: current)
        .accessibilityElement()
        .accessibilityLabel(Text("Page \(current + 1) of \(count)"))
    }
}

private struct TourCardView: View {
    let card: TourCard
    let isCurrent: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)
            TourIllustration(card: card, isCurrent: isCurrent)
                .frame(maxWidth: 320, maxHeight: 300)
            VStack(spacing: 10) {
                Text(card.title)
                    .font(.title.bold())
                    .foregroundStyle(Theme.ink)
                Text(card.text)
                    .font(.body)
                    .foregroundStyle(Theme.muted)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
            Spacer(minLength: 0)
        }
    }
}

/// The live picture on each card.
struct TourIllustration: View {
    let card: TourCard
    let isCurrent: Bool

    @Environment(\.motionEnabled) private var motionEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var effects = MapEffects.none

    private var animate: Bool { motionEnabled && !reduceMotion }

    var body: some View {
        Group {
            switch card {
            case .globe:
                // A slow turn of the globe with sample countries.
                TimelineView(.animation(paused: !animate || !isCurrent)) { timeline in
                    let lon = animate ? 15 + timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 72) * 5 : 15
                    GlobeMap(statusByISO: sampleStatuses,
                             center: .constant(GeoPoint(lon: Projection.normalizedLongitude(lon), lat: 25)),
                             interactive: false, effects: effects)
                }
            case .mark:
                // The status picker trying each option in turn.
                TimelineView(.periodic(from: .now, by: 1.4)) { timeline in
                    let step = animate && isCurrent ? Int(timeline.date.timeIntervalSinceReferenceDate / 1.4) % 3 : 0
                    VStack(spacing: 18) {
                        Text(verbatim: "🇯🇵").font(.system(size: 64))
                        StatusPicker(status: TravelStatus.pickable[step]) { _ in }
                            .allowsHitTesting(false)
                    }
                    .padding(20)
                    .background(Theme.card, in: Theme.cardShape)
                }
            case .photos:
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 56, weight: .regular))
                        .foregroundStyle(Theme.accent)
                        .symbolEffect(.bounce, value: isCurrent && animate)
                    Label("Analysed on this iPhone only", systemImage: "lock")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Theme.card, in: Capsule())
                }
            case .flights:
                FlatMap(statusByISO: sampleStatuses, routes: Self.sampleRoutes, effects: effects)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            case .layouts:
                HStack(spacing: 12) {
                    ForEach(Array(MapLayout.allCases.enumerated()), id: \.element.id) { index, layout in
                        VStack(spacing: 8) {
                            Image(systemName: layout.systemImage)
                                .font(.system(size: 28))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 72, height: 72)
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            Text(layout.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                        }
                        .reveal(index)
                    }
                }
            }
        }
        .accessibilityHidden(true)
        .onChange(of: isCurrent, initial: true) { _, current in
            // Replay the card's effect each time it comes into view.
            guard current, animate else { return }
            switch card {
            case .globe: effects = MapEffects(fillStart: .now)
            case .flights: effects = MapEffects(routeStart: .now)
            default: break
            }
        }
    }

    private static let sampleRoutes: [FlightFigures.Route] = [
        .init(from: GeoPoint(lon: 4.48, lat: 50.90), to: GeoPoint(lon: 23.94, lat: 37.94)),   // Brussels–Athens
        .init(from: GeoPoint(lon: 23.94, lat: 37.94), to: GeoPoint(lon: 55.36, lat: 25.25)),  // Athens–Dubai
        .init(from: GeoPoint(lon: -3.57, lat: 40.47), to: GeoPoint(lon: -77.11, lat: -12.02)), // Madrid–Lima
    ]
}

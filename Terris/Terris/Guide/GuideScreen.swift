//
//  GuideScreen.swift
//  Terris
//
//  "How Terris works": a calm reference page behind the ? button on the Map,
//  with the tour one tap away.
//

import SwiftUI

private struct GuideSection: Identifiable {
    let icon: String
    let title: LocalizedStringKey
    let text: LocalizedStringKey
    let id: Int
}

private let guideSections: [GuideSection] = [
    .init(icon: "globe.europe.africa.fill", title: "The map",
          text: "Countries you've been to are shaded: coral for Visited, teal for Lived, striped amber for Want to go. Drag the globe to spin it; tap a country to open its page.", id: 0),
    .init(icon: "checkmark.circle", title: "Marking a country",
          text: "On a country's page, pick Visited, Lived or Want to go. Tap the selected one again to clear it. Add the cities you went to, your first and last visit, and notes.", id: 1),
    .init(icon: "number", title: "Your count",
          text: "The headline is the countries you've visited or lived in, out of all 197 in Terris. The continent breakdown always adds up to the same number.", id: 2),
    .init(icon: "photo.on.rectangle.angled", title: "Finding countries in your photos",
          text: "The photo button reads where your photos were taken and suggests the countries. Nothing is added until you tap Add to my map, and your photos never leave your iPhone.", id: 3),
    .init(icon: "airplane", title: "Flights",
          text: "Log a flight with the + on the Flights tab: pick the airports right in the route card, add times, seat and notes. Long-press a flight to delete it.", id: 4),
    .init(icon: "square.3.layers.3d", title: "Globe, Journal or Atlas",
          text: "The layers button switches how the map tab looks. Terris remembers your choice.", id: 5),
    .init(icon: "magnifyingglass", title: "Search",
          text: "The search tab finds any country by name or code, even ones you haven't been to, so you can read about it or add it to your wishlist.", id: 6),
    .init(icon: "icloud", title: "Your devices and privacy",
          text: "Your map syncs through your own iCloud to your other devices. There's no account, no tracking and no ads.", id: 7),
]

struct GuideScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingTour = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Button { showingTour = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "play.circle.fill")
                                .font(.title)
                                .foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Take the tour").font(.headline).foregroundStyle(Theme.ink)
                                Text("Five quick cards on the basics").font(.subheadline).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                        }
                        .card()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .reveal(0)

                    ForEach(Array(guideSections.enumerated()), id: \.element.id) { index, section in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: section.icon)
                                .font(.title3)
                                .foregroundStyle(Theme.accent)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(section.title).font(.headline).foregroundStyle(Theme.ink)
                                Text(section.text).font(.subheadline).foregroundStyle(Theme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .card()
                        .accessibilityElement(children: .combine)
                        .reveal(index + 1)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle("How Terris works")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Label("Close", systemImage: "xmark") }
                }
            }
        }
        .fullScreenCover(isPresented: $showingTour) { TourScreen() }
    }
}

//
//  GlobeView.swift
//  Terris
//
//  Interactive Apple Maps globe using SwiftUI Map with high-altitude camera.
//  Coloured circle overlays per TravelStatus. Tap a marker to select a country.
//

import SwiftUI
import MapKit
import CoreData

// MARK: - SwiftUI Map-based Globe

struct GlobeView: View {
    var viewModel: GlobeViewModel
    let countries: [Country]

    // Start with a high-altitude camera centred on Europe/Africa
    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 20, longitude: 10),
            distance: 15_000_000,
            heading: 0,
            pitch: 0
        )
    )

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(mapItems, id: \.isoCode) { item in
                Annotation(item.name, coordinate: item.coordinate) {
                    CountryPinView(item: item) {
                        NotificationCenter.default.post(
                            name: .globeCountryTapped,
                            object: nil,
                            userInfo: ["isoCode": item.isoCode]
                        )
                    }
                }
            }
        }
        .mapStyle(.hybrid(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .ignoresSafeArea()
        .onChange(of: viewModel.selectedCountry) { _, country in
            if let country,
               let iso = country.isoCode,
               let (lat, lon) = CountryCentroids.all[iso] {
                withAnimation(.easeInOut(duration: 0.8)) {
                    cameraPosition = .camera(MapCamera(
                        centerCoordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        distance: 4_000_000,
                        heading: 0,
                        pitch: 0
                    ))
                }
            }
        }
    }

    // Build lightweight display items from CoreData objects
    private var mapItems: [CountryMapItem] {
        let centroids = CountryCentroids.all
        let searchedISO = viewModel.searchedISOCode
        return countries.compactMap { country in
            guard let iso = country.isoCode,
                  let (lat, lon) = centroids[iso] else { return nil }
            let status = TravelStatus(rawValue: country.status) ?? .none
            let isHighlighted = (iso == searchedISO)
            // Show pin if: has a status OR is the searched country
            guard status != .none || isHighlighted else { return nil }
            return CountryMapItem(
                isoCode: iso,
                name: country.name ?? iso,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                status: status,
                isHighlighted: isHighlighted
            )
        }
    }
}

// MARK: - Lightweight value type for map rendering

struct CountryMapItem {
    let isoCode: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let status: TravelStatus
    var isHighlighted: Bool = false
}

// MARK: - Pin view

struct CountryPinView: View {
    let item: CountryMapItem
    let onTap: () -> Void
    @State private var isPressed = false
    @State private var pulse = false

    // Highlighted (search result) → white pin
    // Otherwise → status colour
    private var pinColor: Color {
        item.isHighlighted ? .white : item.status.color
    }

    private var iconColor: Color {
        item.isHighlighted ? Color(.systemGray) : .white
    }

    private var pinIcon: String {
        item.isHighlighted && item.status == .none ? "magnifyingglass" : item.status.icon
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                ZStack {
                    // Pulsing ring for highlighted search result
                    if item.isHighlighted {
                        Circle()
                            .stroke(Color.white.opacity(pulse ? 0 : 0.7), lineWidth: 2)
                            .frame(width: pulse ? 52 : 36, height: pulse ? 52 : 36)
                            .animation(
                                .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                                value: pulse
                            )
                    }

                    // Main circle
                    Circle()
                        .fill(pinColor)
                        .frame(
                            width: item.isHighlighted ? 34 : 28,
                            height: item.isHighlighted ? 34 : 28
                        )
                        .shadow(
                            color: pinColor.opacity(item.isHighlighted ? 0.9 : 0.6),
                            radius: item.isHighlighted ? 8 : 4,
                            x: 0, y: 2
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    item.isHighlighted ? Color(.systemGray3) : Color.clear,
                                    lineWidth: 1.5
                                )
                        )

                    Image(systemName: pinIcon)
                        .font(.system(size: item.isHighlighted ? 14 : 12, weight: .bold))
                        .foregroundStyle(iconColor)
                }

                // Country label
                Text(item.name)
                    .font(.system(size: item.isHighlighted ? 9 : 8, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        item.isHighlighted
                            ? AnyShapeStyle(Color.white.opacity(0.25))
                            : AnyShapeStyle(.ultraThinMaterial),
                        in: Capsule()
                    )
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 1.15 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
        .onAppear {
            if item.isHighlighted { pulse = true }
        }
        .onChange(of: item.isHighlighted) { _, highlighted in
            pulse = highlighted
        }
    }
}

// MARK: - Notification name (shared)

extension Notification.Name {
    static let globeCountryTapped = Notification.Name("globeCountryTapped")
}

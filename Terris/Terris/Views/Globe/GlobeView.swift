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
        return countries.compactMap { country in
            guard let iso = country.isoCode,
                  let (lat, lon) = centroids[iso] else { return nil }
            let status = TravelStatus(rawValue: country.status) ?? .none
            // Only show pins for marked countries (reduces clutter)
            guard status != .none else { return nil }
            return CountryMapItem(
                isoCode: iso,
                name: country.name ?? iso,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                status: status
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
}

// MARK: - Pin view

struct CountryPinView: View {
    let item: CountryMapItem
    let onTap: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(item.status.color)
                        .frame(width: 28, height: 28)
                        .shadow(color: item.status.color.opacity(0.6), radius: 4, x: 0, y: 2)
                    Image(systemName: item.status.icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                // Small country name label
                Text(item.name)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.ultraThinMaterial, in: Capsule())
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 1.2 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Notification name (shared)

extension Notification.Name {
    static let globeCountryTapped = Notification.Name("globeCountryTapped")
}

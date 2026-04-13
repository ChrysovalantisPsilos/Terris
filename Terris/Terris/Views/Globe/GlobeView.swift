//
//  GlobeView.swift
//  Terris
//
//  MKMapView with MKPolygon country overlays loaded from countries.geojson.
//  - Every country body is filled with its TravelStatus colour.
//  - Tapping anywhere on a country selects it (no pin needed).
//  - The searched/selected country gets a bright white highlight fill + thick border.
//

import SwiftUI
import MapKit

// MARK: - SwiftUI wrapper

struct GlobeView: UIViewRepresentable {
    var viewModel: GlobeViewModel
    let countries: [Country]

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, countries: countries)
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.mapType = .hybridFlyover
        map.showsUserLocation = false
        map.showsCompass = true
        map.isRotateEnabled = true
        map.isPitchEnabled = false
        map.delegate = context.coordinator
        context.coordinator.mapView = map

        // Start at a high altitude globe-like view
        map.camera = MKMapCamera(
            lookingAtCenter: CLLocationCoordinate2D(latitude: 20, longitude: 10),
            fromDistance: 15_000_000,
            pitch: 0,
            heading: 0
        )

        // Tap recognizer — hit-tests polygon overlays
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)

        // Load GeoJSON polygons on a background thread
        context.coordinator.loadPolygons()

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.countries = countries
        context.coordinator.refreshOverlayColors()

        // Fly to selected country
        if let iso = viewModel.selectedCountry?.isoCode,
           iso != context.coordinator.lastFlyToISO,
           let (lat, lon) = CountryCentroids.all[iso] {
            context.coordinator.lastFlyToISO = iso
            let camera = MKMapCamera(
                lookingAtCenter: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                fromDistance: 3_500_000, pitch: 0, heading: 0
            )
            map.setCamera(camera, animated: true)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var viewModel: GlobeViewModel
        var countries: [Country]
        weak var mapView: MKMapView?
        var lastFlyToISO: String? = nil

        // iso → [MKPolygon] (multi-polygon countries have many rings)
        var polygonsByISO: [String: [MKPolygon]] = [:]
        // polygon → iso (reverse lookup for tap hit-test)
        var isoByPolygon: [MKPolygon: String] = [:]

        init(viewModel: GlobeViewModel, countries: [Country]) {
            self.viewModel = viewModel
            self.countries = countries
        }

        // MARK: Load GeoJSON

        func loadPolygons() {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self,
                      let url = Bundle.main.url(forResource: "countries", withExtension: "geojson"),
                      let data = try? Data(contentsOf: url),
                      let features = try? MKGeoJSONDecoder().decode(data) else { return }

                var byISO: [String: [MKPolygon]] = [:]
                var byPolygon: [MKPolygon: String] = [:]

                for item in features {
                    guard let feature = item as? MKGeoJSONFeature,
                          let propData = feature.properties,
                          let props = try? JSONSerialization.jsonObject(with: propData) as? [String: Any],
                          let iso = props["ISO_A2"] as? String,
                          iso != "-99", iso != "" else { continue }

                    for geo in feature.geometry {
                        let polys: [MKPolygon]
                        if let poly = geo as? MKPolygon {
                            polys = [poly]
                        } else if let multi = geo as? MKMultiPolygon {
                            polys = multi.polygons
                        } else { continue }

                        for poly in polys {
                            poly.title = iso          // store ISO in title for quick lookup
                            byISO[iso, default: []].append(poly)
                            byPolygon[poly] = iso
                        }
                    }
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self, let map = self.mapView else { return }
                    self.polygonsByISO = byISO
                    self.isoByPolygon = byPolygon
                    let all = Array(byPolygon.keys)
                    map.addOverlays(all, level: .aboveRoads)
                }
            }
        }

        // MARK: Tap handling — hit-test all polygons

        @objc func handleTap(_ gr: UITapGestureRecognizer) {
            guard let map = mapView else { return }
            let pt = gr.location(in: map)
            let coord = map.convert(pt, toCoordinateFrom: map)
            let mapPt = MKMapPoint(coord)

            // Walk all visible overlays and find the smallest polygon that contains the tap
            var best: (iso: String, area: Double)? = nil
            for (poly, iso) in isoByPolygon {
                let renderer = map.renderer(for: poly) as? MKPolygonRenderer
                    ?? MKPolygonRenderer(polygon: poly)
                let polyPt = renderer.point(for: mapPt)
                if renderer.path?.contains(polyPt) == true {
                    let area = poly.boundingMapRect.size.width * poly.boundingMapRect.size.height
                    if best == nil || area < best!.area {
                        best = (iso, area)
                    }
                }
            }

            if let iso = best?.iso {
                NotificationCenter.default.post(
                    name: .globeCountryTapped,
                    object: nil,
                    userInfo: ["isoCode": iso]
                )
            }
        }

        // Allow tap gesture to coexist with map's built-in gestures
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }

        // MARK: Overlay renderer

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let poly = overlay as? MKPolygon else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolygonRenderer(polygon: poly)
            apply(renderer: renderer, iso: poly.title ?? "")
            return renderer
        }

        // MARK: Colour logic

        func apply(renderer: MKPolygonRenderer, iso: String) {
            let country = countries.first { $0.isoCode == iso }
            let status = TravelStatus(rawValue: country?.status ?? 0) ?? .none
            let selectedISO = viewModel.selectedCountry?.isoCode
            let searchedISO = viewModel.searchedISOCode
            let isSelected = (iso == selectedISO)
            let isSearched = (iso == searchedISO)

            switch (isSelected, isSearched, status) {
            case (true, _, _):
                // Selected: bright white fill + thick accent border
                renderer.fillColor = UIColor.white.withAlphaComponent(0.35)
                renderer.strokeColor = UIColor.white
                renderer.lineWidth = 2.5
            case (_, true, .none):
                // Searched, unvisited: white highlight
                renderer.fillColor = UIColor.white.withAlphaComponent(0.25)
                renderer.strokeColor = UIColor.white.withAlphaComponent(0.9)
                renderer.lineWidth = 2.0
            case (_, true, _):
                // Searched + has status: status colour brightened
                renderer.fillColor = uiColor(for: status).withAlphaComponent(0.55)
                renderer.strokeColor = UIColor.white
                renderer.lineWidth = 2.0
            case (_, _, .none):
                // Unvisited: faint outline only
                renderer.fillColor = UIColor.clear
                renderer.strokeColor = UIColor.white.withAlphaComponent(0.08)
                renderer.lineWidth = 0.5
            default:
                // Has status, not selected/searched: normal fill
                renderer.fillColor = uiColor(for: status).withAlphaComponent(0.45)
                renderer.strokeColor = uiColor(for: status).withAlphaComponent(0.8)
                renderer.lineWidth = 1.0
            }
        }

        func uiColor(for status: TravelStatus) -> UIColor {
            switch status {
            case .none:        return .systemGray
            case .wantToVisit: return UIColor(red: 0.655, green: 0.545, blue: 0.980, alpha: 1)
            case .visited:     return UIColor(red: 0.306, green: 0.804, blue: 0.769, alpha: 1)
            case .livedIn:     return UIColor(red: 1.0,   green: 0.820, blue: 0.400, alpha: 1)
            }
        }

        // MARK: Refresh all overlay colours (called on status change / selection change)

        func refreshOverlayColors() {
            guard let map = mapView else { return }
            for overlay in map.overlays {
                guard let poly = overlay as? MKPolygon,
                      let renderer = map.renderer(for: poly) as? MKPolygonRenderer else { continue }
                apply(renderer: renderer, iso: poly.title ?? "")
                renderer.invalidatePath()
            }
        }
    }
}

// MARK: - Notification name (shared)

extension Notification.Name {
    static let globeCountryTapped = Notification.Name("globeCountryTapped")
}

//
//  GlobeView.swift
//  Terris
//
//  MKMapView with MKPolygon country overlays loaded from countries.geojson.
//  - Every country body is filled with its TravelStatus colour.
//  - Tapping anywhere on a country selects it (no pin needed).
//  - The searched/selected country gets a bright white highlight fill + thick border.
//  - Visited cities appear as small MKMarkerAnnotationView pins (geocoded once via MKLocalSearch).
//

import SwiftUI
import MapKit
import CoreData

// MARK: - SwiftUI wrapper

struct GlobeView: UIViewRepresentable {
    var viewModel: GlobeViewModel
    let countries: [Country]
    var cities: [City] = []

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

        map.camera = MKMapCamera(
            lookingAtCenter: CLLocationCoordinate2D(latitude: 20, longitude: 10),
            fromDistance: 15_000_000, pitch: 0, heading: 0
        )

        map.register(CityPinView.self,
                     forAnnotationViewWithReuseIdentifier: CityPinView.reuseID)

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)

        context.coordinator.loadPolygons()

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleStatusChanged(_:)),
            name: .countryStatusChanged,
            object: nil
        )

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.countries = countries
        context.coordinator.refreshOverlayColors()
        context.coordinator.syncCityPins(cities: cities, in: map)

        // Fly to selected country
        if let iso = viewModel.selectedCountry?.isoCode,
           iso != context.coordinator.lastFlyToISO,
           let (lat, lon) = CountryCentroids.all[iso] {
            context.coordinator.lastFlyToISO = iso
            map.setCamera(
                MKMapCamera(lookingAtCenter: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                            fromDistance: 3_500_000, pitch: 0, heading: 0),
                animated: true
            )
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var viewModel: GlobeViewModel
        var countries: [Country]
        weak var mapView: MKMapView?
        var lastFlyToISO: String? = nil

        var polygonsByISO: [String: [MKPolygon]] = [:]
        var isoByPolygon: [MKPolygon: String] = [:]

        // City pin tracking
        var cityAnnotations: [NSManagedObjectID: CityAnnotation] = [:]
        var cityCoords: [NSManagedObjectID: CLLocationCoordinate2D] = [:]
        var geocodingInFlight: Set<NSManagedObjectID> = []

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

                // Some countries have ISO_A2 = "-99" in Natural Earth data.
                // Map their names to the correct ISO codes.
                let nameToISO: [String: String] = [
                    "France": "FR", "Norway": "NO", "Kosovo": "XK",
                    "Northern Cyprus": "CY", "Somaliland": "SO"
                ]

                for item in features {
                    guard let feature = item as? MKGeoJSONFeature,
                          let propData = feature.properties,
                          let props = try? JSONSerialization.jsonObject(with: propData) as? [String: Any]
                    else { continue }

                    var isoRaw = props["ISO_A2"] as? String ?? ""
                    if isoRaw == "-99" || isoRaw.isEmpty {
                        guard let name = props["name"] as? String,
                              let mapped = nameToISO[name] else { continue }
                        isoRaw = mapped
                    }
                    let iso = isoRaw

                    for geo in feature.geometry {
                        let polys: [MKPolygon]
                        if let poly = geo as? MKPolygon { polys = [poly] }
                        else if let multi = geo as? MKMultiPolygon { polys = multi.polygons }
                        else { continue }

                        for poly in polys {
                            poly.title = iso
                            byISO[iso, default: []].append(poly)
                            byPolygon[poly] = iso
                        }
                    }
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self, let map = self.mapView else { return }
                    self.polygonsByISO = byISO
                    self.isoByPolygon = byPolygon
                    map.addOverlays(Array(byPolygon.keys), level: .aboveRoads)
                }
            }
        }

        // MARK: City pin sync

        func syncCityPins(cities: [City], in map: MKMapView) {
            let currentIDs = Set(cities.map { $0.objectID })

            // Remove pins for cities no longer in the list
            for (id, ann) in cityAnnotations where !currentIDs.contains(id) {
                map.removeAnnotation(ann)
                cityAnnotations.removeValue(forKey: id)
            }

            // Add / update pins
            for city in cities {
                let id = city.objectID
                if let ann = cityAnnotations[id] {
                    let status = TravelStatus(rawValue: city.status) ?? .none
                    if ann.status != status {
                        ann.status = status
                        if let view = map.view(for: ann) as? CityPinView {
                            view.applyStatus(status)
                        }
                    }
                } else {
                    geocodeCity(city, in: map)
                }
            }
        }

        private func geocodeCity(_ city: City, in map: MKMapView) {
            let id = city.objectID
            guard !geocodingInFlight.contains(id) else { return }

            if let coord = cityCoords[id] {
                addCityPin(city: city, coord: coord, in: map)
                return
            }

            geocodingInFlight.insert(id)
            let cityName    = city.name ?? ""
            let countryName = city.region?.country?.name ?? ""
            let query       = [cityName, countryName].filter { !$0.isEmpty }.joined(separator: ", ")
            guard !query.isEmpty else { geocodingInFlight.remove(id); return }

            let req = MKLocalSearch.Request()
            req.naturalLanguageQuery = query
            req.resultTypes = .address

            MKLocalSearch(request: req).start { [weak self] response, _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.geocodingInFlight.remove(id)
                    guard let coord = response?.mapItems.first?.placemark.coordinate else { return }
                    self.cityCoords[id] = coord
                    self.addCityPin(city: city, coord: coord, in: map)
                }
            }
        }

        private func addCityPin(city: City, coord: CLLocationCoordinate2D, in map: MKMapView) {
            let id = city.objectID
            guard cityAnnotations[id] == nil else { return }
            let status = TravelStatus(rawValue: city.status) ?? .none
            let ann = CityAnnotation(cityName: city.name ?? "", coordinate: coord, status: status)
            cityAnnotations[id] = ann
            map.addAnnotation(ann)
        }

        // MARK: Status change

        @objc func handleStatusChanged(_ notification: Notification) {
            refreshOverlayColors()
        }

        // MARK: Tap handling

        @objc func handleTap(_ gr: UITapGestureRecognizer) {
            guard let map = mapView else { return }
            let pt    = gr.location(in: map)
            let coord = map.convert(pt, toCoordinateFrom: map)
            let mapPt = MKMapPoint(coord)

            // Among all polygons that contain the tap point, pick the one with
            // the LARGEST area. This correctly handles countries with overseas
            // territories (France, Portugal, etc.) — the mainland polygon is
            // always larger than any remote territory, so it wins.
            var best: (iso: String, area: Double)? = nil
            for (poly, iso) in isoByPolygon {
                let renderer = map.renderer(for: poly) as? MKPolygonRenderer
                    ?? MKPolygonRenderer(polygon: poly)
                let polyPt = renderer.point(for: mapPt)
                guard renderer.path?.contains(polyPt) == true else { continue }

                let area = poly.boundingMapRect.width * poly.boundingMapRect.height
                if best == nil || area > best!.area {
                    best = (iso, area)
                }
            }

            if let iso = best?.iso {
                NotificationCenter.default.post(
                    name: .globeCountryTapped, object: nil,
                    userInfo: ["isoCode": iso]
                )
            }
        }

        func gestureRecognizer(_ gr: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        // MARK: Annotation view

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let city = annotation as? CityAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: CityPinView.reuseID, for: city) as! CityPinView
            view.applyStatus(city.status)
            return view
        }

        // MARK: Overlay renderer

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let poly = overlay as? MKPolygon else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolygonRenderer(polygon: poly)
            apply(renderer: renderer, iso: poly.title ?? "")
            return renderer
        }

        // MARK: Colour logic

        func apply(renderer: MKPolygonRenderer, iso: String) {
            let country    = countries.first { $0.isoCode == iso }
            let status     = TravelStatus(rawValue: country?.status ?? 0) ?? .none
            let isSelected = (iso == viewModel.selectedCountry?.isoCode)
            let isSearched = (iso == viewModel.searchedISOCode)

            switch (isSelected, isSearched, status) {
            case (true, _, _):
                renderer.fillColor   = UIColor.white.withAlphaComponent(0.35)
                renderer.strokeColor = UIColor.white
                renderer.lineWidth   = 2.5
            case (_, true, .none):
                renderer.fillColor   = UIColor.white.withAlphaComponent(0.25)
                renderer.strokeColor = UIColor.white.withAlphaComponent(0.9)
                renderer.lineWidth   = 2.0
            case (_, true, _):
                renderer.fillColor   = uiColor(for: status).withAlphaComponent(0.55)
                renderer.strokeColor = UIColor.white
                renderer.lineWidth   = 2.0
            case (_, _, .none):
                renderer.fillColor   = UIColor.clear
                renderer.strokeColor = UIColor.white.withAlphaComponent(0.08)
                renderer.lineWidth   = 0.5
            default:
                renderer.fillColor   = uiColor(for: status).withAlphaComponent(0.45)
                renderer.strokeColor = uiColor(for: status).withAlphaComponent(0.8)
                renderer.lineWidth   = 1.0
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

// MARK: - City annotation

final class CityAnnotation: NSObject, MKAnnotation {
    let cityName: String
    dynamic var coordinate: CLLocationCoordinate2D
    var status: TravelStatus

    init(cityName: String, coordinate: CLLocationCoordinate2D, status: TravelStatus) {
        self.cityName   = cityName
        self.coordinate = coordinate
        self.status     = status
    }

    var title: String? { cityName }
}

// MARK: - City pin view

final class CityPinView: MKMarkerAnnotationView {
    static let reuseID = "CityPin"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        canShowCallout    = true
        animatesWhenAdded = true
        displayPriority   = .defaultLow   // hidden at globe altitude, visible when zoomed in
    }

    required init?(coder: NSCoder) { fatalError() }

    func applyStatus(_ status: TravelStatus) {
        let cfg = UIImage.SymbolConfiguration(pointSize: 8, weight: .bold)
        switch status {
        case .none:
            markerTintColor = UIColor.systemGray.withAlphaComponent(0.5)
            glyphImage = nil; glyphText = "·"
        case .wantToVisit:
            markerTintColor = UIColor(red: 0.655, green: 0.545, blue: 0.980, alpha: 1)
            glyphImage = UIImage(systemName: "bookmark.fill", withConfiguration: cfg)
            glyphText  = nil
        case .visited:
            markerTintColor = UIColor(red: 0.306, green: 0.804, blue: 0.769, alpha: 1)
            glyphImage = UIImage(systemName: "checkmark", withConfiguration: cfg)
            glyphText  = nil
        case .livedIn:
            markerTintColor = UIColor(red: 1.0, green: 0.820, blue: 0.400, alpha: 1)
            glyphImage = UIImage(systemName: "house.fill", withConfiguration: cfg)
            glyphText  = nil
        }
    }
}

// MARK: - Notification names (shared)

extension Notification.Name {
    static let globeCountryTapped   = Notification.Name("globeCountryTapped")
    static let countryStatusChanged = Notification.Name("countryStatusChanged")
}


// MARK: - SwiftUI wrapper

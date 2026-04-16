//
//  GlobeView.swift
//  Terris
//

import SwiftUI
import MapKit
import CoreData

struct GlobeView: UIViewRepresentable {
    var viewModel: GlobeViewModel
    let countries: [Country]
    var cities: [City] = []

    func makeCoordinator() -> Coordinator { Coordinator(viewModel: viewModel) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.mapType = .hybridFlyover
        map.showsUserLocation = false
        map.showsCompass = true
        map.isRotateEnabled = true
        map.isPitchEnabled = false
        map.delegate = context.coordinator
        context.coordinator.mapView = map
        map.camera = MKMapCamera(lookingAtCenter: CLLocationCoordinate2D(latitude: 20, longitude: 10),
                                 fromDistance: 15_000_000, pitch: 0, heading: 0)
        map.register(CityPinView.self, forAnnotationViewWithReuseIdentifier: CityPinView.reuseID)
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)
        context.coordinator.loadPolygons()
        NotificationCenter.default.addObserver(context.coordinator,
            selector: #selector(Coordinator.handleStatusChanged(_:)),
            name: .countryStatusChanged, object: nil)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let c = context.coordinator

        // Rebuild O(1) status cache only when data changed
        let newSnapshot: [(String, Int16)] = countries.compactMap {
            guard let iso = $0.isoCode else { return nil }
            return (iso, $0.status)
        }
        let changed = newSnapshot.count != c.lastCountrySnapshot.count ||
            zip(newSnapshot, c.lastCountrySnapshot).contains { $0.0 != $1.0 || $0.1 != $1.1 }

        if changed {
            c.lastCountrySnapshot = newSnapshot
            c.isoToStatus = Dictionary(uniqueKeysWithValues: newSnapshot)
            c.refreshOverlayColors()
        }

        // Fly to selected country
        if let iso = viewModel.selectedCountry?.isoCode,
           iso != c.lastFlyToISO,
           let (lat, lon) = CountryCentroids.all[iso] {
            c.lastFlyToISO = iso
            map.setCamera(MKMapCamera(lookingAtCenter: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                      fromDistance: 3_500_000, pitch: 0, heading: 0), animated: true)
        }

        c.syncCityPins(cities: cities, in: map)
        c.viewModel = viewModel
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var viewModel: GlobeViewModel
        weak var mapView: MKMapView?
        var lastFlyToISO: String?

        // O(1) status lookup
        var isoToStatus: [String: Int16] = [:]
        var lastCountrySnapshot: [(String, Int16)] = []
        var lastSelectedISO: String?
        var lastSearchedISO: String?

        // City geocoding
        var cityAnnotations: [NSManagedObjectID: CityAnnotation] = [:]
        var cityCoords:       [NSManagedObjectID: CLLocationCoordinate2D] = [:]
        var geocodingInFlight: Set<NSManagedObjectID> = []
        private let geocodeSemaphore = DispatchSemaphore(value: 3)

        init(viewModel: GlobeViewModel) { self.viewModel = viewModel }

        // MARK: Load GeoJSON

        func loadPolygons() {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                autoreleasepool {
                    guard let url = Bundle.main.url(forResource: "countries", withExtension: "geojson"),
                          let data = try? Data(contentsOf: url),
                          let features = try? MKGeoJSONDecoder().decode(data) else { return }

                    let nameToISO: [String: String] = [
                        "France": "FR", "Norway": "NO", "Kosovo": "XK",
                        "Northern Cyprus": "CY", "Somaliland": "SO"
                    ]
                    var allPolygons: [MKPolygon] = []

                    for item in features {
                        autoreleasepool {
                            guard let feature = item as? MKGeoJSONFeature,
                                  let propData = feature.properties,
                                  let props = try? JSONSerialization.jsonObject(with: propData) as? [String: Any]
                            else { return }

                            var isoRaw = props["ISO_A2"] as? String ?? ""
                            if isoRaw == "-99" || isoRaw.isEmpty {
                                guard let name = props["name"] as? String,
                                      let mapped = nameToISO[name] else { return }
                                isoRaw = mapped
                            }
                            let iso = isoRaw
                            for geo in feature.geometry {
                                let polys: [MKPolygon]
                                if let p = geo as? MKPolygon { polys = [p] }
                                else if let m = geo as? MKMultiPolygon { polys = m.polygons }
                                else { continue }
                                for poly in polys { poly.title = iso; allPolygons.append(poly) }
                            }
                        }
                    }

                    DispatchQueue.main.async { [weak self] in
                        guard let self, let map = self.mapView else { return }
                        map.addOverlays(allPolygons, level: .aboveRoads)
                    }
                }
            }
        }

        // MARK: City pin sync

        func syncCityPins(cities: [City], in map: MKMapView) {
            let currentIDs = Set(cities.map { $0.objectID })
            for (id, ann) in cityAnnotations where !currentIDs.contains(id) {
                map.removeAnnotation(ann); cityAnnotations.removeValue(forKey: id)
            }
            for city in cities {
                let id = city.objectID
                if let ann = cityAnnotations[id] {
                    let s = TravelStatus(rawValue: city.status) ?? .none
                    if ann.status != s { ann.status = s; (map.view(for: ann) as? CityPinView)?.applyStatus(s) }
                } else { geocodeCity(city, in: map) }
            }
        }

        private func geocodeCity(_ city: City, in map: MKMapView) {
            let id = city.objectID
            guard !geocodingInFlight.contains(id) else { return }
            if let coord = cityCoords[id] { addCityPin(city: city, coord: coord, in: map); return }
            geocodingInFlight.insert(id)
            let query = [city.name, city.region?.country?.name].compactMap { $0 }
                .filter { !$0.isEmpty }.joined(separator: ", ")
            guard !query.isEmpty else { geocodingInFlight.remove(id); return }
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self else { return }
                self.geocodeSemaphore.wait()
                let req = MKLocalSearch.Request()
                req.naturalLanguageQuery = query; req.resultTypes = .address
                MKLocalSearch(request: req).start { [weak self] response, _ in
                    defer { self?.geocodeSemaphore.signal() }
                    DispatchQueue.main.async {
                        guard let self else { return }
                        self.geocodingInFlight.remove(id)
                        guard let coord = response?.mapItems.first?.location.coordinate else { return }
                        self.cityCoords[id] = coord
                        self.addCityPin(city: city, coord: coord, in: map)
                    }
                }
            }
        }

        private func addCityPin(city: City, coord: CLLocationCoordinate2D, in map: MKMapView) {
            guard cityAnnotations[city.objectID] == nil else { return }
            let ann = CityAnnotation(cityName: city.name ?? "", coordinate: coord,
                                     status: TravelStatus(rawValue: city.status) ?? .none)
            cityAnnotations[city.objectID] = ann
            map.addAnnotation(ann)
        }

        @objc func handleStatusChanged(_ n: Notification) { refreshOverlayColors() }

        // MARK: Tap — reuse cached renderers only

        @objc func handleTap(_ gr: UITapGestureRecognizer) {
            guard let map = mapView else { return }
            let mapPt = MKMapPoint(map.convert(gr.location(in: map), toCoordinateFrom: map))
            var best: (iso: String, area: Double)?
            for overlay in map.overlays {
                guard let poly = overlay as? MKPolygon,
                      let iso = poly.title, !iso.isEmpty,
                      let renderer = map.renderer(for: poly) as? MKPolygonRenderer else { continue }
                guard renderer.path?.contains(renderer.point(for: mapPt)) == true else { continue }
                let area = poly.boundingMapRect.width * poly.boundingMapRect.height
                if best == nil || area > best!.area { best = (iso, area) }
            }
            if let iso = best?.iso {
                NotificationCenter.default.post(name: .globeCountryTapped, object: nil,
                                                userInfo: ["isoCode": iso])
            }
        }

        func gestureRecognizer(_ gr: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        // MARK: Annotation view

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let city = annotation as? CityAnnotation else { return nil }
            let v = mapView.dequeueReusableAnnotationView(
                withIdentifier: CityPinView.reuseID, for: city) as! CityPinView
            v.applyStatus(city.status); return v
        }

        // MARK: Overlay renderer — created once per overlay by MapKit

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let poly = overlay as? MKPolygon else { return MKOverlayRenderer(overlay: overlay) }
            let r = MKPolygonRenderer(polygon: poly)
            apply(renderer: r, iso: poly.title ?? ""); return r
        }

        // MARK: Colour logic

        func apply(renderer: MKPolygonRenderer, iso: String) {
            let status     = TravelStatus(rawValue: isoToStatus[iso] ?? 0) ?? .none
            let isSelected = iso == viewModel.selectedCountry?.isoCode
            let isSearched = iso == viewModel.searchedISOCode

            switch (isSelected, isSearched, status) {
            case (true, _, _):
                renderer.fillColor = UIColor.white.withAlphaComponent(0.35)
                renderer.strokeColor = UIColor.white; renderer.lineWidth = 2.5
            case (_, true, .none):
                renderer.fillColor = UIColor.white.withAlphaComponent(0.25)
                renderer.strokeColor = UIColor.white.withAlphaComponent(0.9); renderer.lineWidth = 2.0
            case (_, true, _):
                renderer.fillColor = uiColor(for: status).withAlphaComponent(0.55)
                renderer.strokeColor = UIColor.white; renderer.lineWidth = 2.0
            case (_, _, .none):
                renderer.fillColor = .clear
                renderer.strokeColor = UIColor.white.withAlphaComponent(0.08); renderer.lineWidth = 0.5
            default:
                renderer.fillColor = uiColor(for: status).withAlphaComponent(0.45)
                renderer.strokeColor = uiColor(for: status).withAlphaComponent(0.8); renderer.lineWidth = 1.0
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
            let selISO  = viewModel.selectedCountry?.isoCode
            let srchISO = viewModel.searchedISOCode
            let relevant = Set([selISO, srchISO, lastSelectedISO, lastSearchedISO].compactMap { $0 })
            lastSelectedISO = selISO; lastSearchedISO = srchISO
            for overlay in map.overlays {
                guard let poly = overlay as? MKPolygon, let iso = poly.title,
                      let r = map.renderer(for: poly) as? MKPolygonRenderer else { continue }
                guard relevant.contains(iso) || (isoToStatus[iso] ?? 0) != 0 else { continue }
                apply(renderer: r, iso: iso); r.setNeedsDisplay()
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
        self.cityName = cityName; self.coordinate = coordinate; self.status = status
    }
    var title: String? { cityName }
}

// MARK: - City pin view

final class CityPinView: MKMarkerAnnotationView {
    static let reuseID = "CityPin"
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        canShowCallout = true; animatesWhenAdded = true; displayPriority = .defaultLow
    }
    required init?(coder: NSCoder) { fatalError() }
    func applyStatus(_ status: TravelStatus) {
        let cfg = UIImage.SymbolConfiguration(pointSize: 8, weight: .bold)
        switch status {
        case .none:
            markerTintColor = .systemGray; glyphText = "·"; glyphImage = nil
        case .wantToVisit:
            markerTintColor = UIColor(red: 0.655, green: 0.545, blue: 0.980, alpha: 1)
            glyphImage = UIImage(systemName: "bookmark.fill", withConfiguration: cfg); glyphText = nil
        case .visited:
            markerTintColor = UIColor(red: 0.306, green: 0.804, blue: 0.769, alpha: 1)
            glyphImage = UIImage(systemName: "checkmark", withConfiguration: cfg); glyphText = nil
        case .livedIn:
            markerTintColor = UIColor(red: 1.0, green: 0.820, blue: 0.400, alpha: 1)
            glyphImage = UIImage(systemName: "house.fill", withConfiguration: cfg); glyphText = nil
        }
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let globeCountryTapped   = Notification.Name("globeCountryTapped")
    static let countryStatusChanged = Notification.Name("countryStatusChanged")
}

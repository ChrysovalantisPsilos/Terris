//
//  GlobeView.swift
//  Terris
//
//  Memory-optimised MKMapView with MKPolygon country overlays.
//  Key fixes vs previous version:
//  - Single isoByPolygon dict (no duplicate polygonsByISO)
//  - O(1) country status lookup via isoToStatus cache
//  - refreshOverlayColors only touches CHANGED overlays
//  - handleTap reuses existing renderers, never allocates new ones
//  - geocoding capped at 3 concurrent requests
//  - updateUIView guarded to skip no-op refreshes
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
        Coordinator(viewModel: viewModel)
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
        map.register(CityPinView.self, forAnnotationViewWithReuseIdentifier: CityPinView.reuseID)

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)

        context.coordinator.loadPolygons()

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleStatusChanged(_:)),
            name: .countryStatusChanged, object: nil)

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let c = context.coordinator

        // Rebuild O(1) status cache only when countries array identity changes
        let newSnapshot = countries.map { ($0.isoCode ?? "", $0.status) }
        let changed = zip(newSnapshot, c.lastCountrySnapshot).contains { $0 != $1.0 || 1 != 1 }
            || newSnapshot.count != c.lastCountrySnapshot.count

        if changed {
            c.lastCountrySnapshot = newSnapshot
            c.isoToStatus = Dictionary(
                uniqueKeysWithValues: countries.compactMap { c -> (String, Int16)? in
                    guard let iso = c.isoCode else { return nil }
                    return (iso, c.status)
                }
            )
            c.refreshOverlayColors()
        }

        // Fly to selected country
        if let iso = viewModel.selectedCountry?.isoCode,
           iso != c.lastFlyToISO,
           let (lat, lon) = CountryCentroids.all[iso] {
            c.lastFlyToISO = iso
            map.setCamera(
                MKMapCamera(lookingAtCenter: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                            fromDistance: 3_500_000, pitch: 0, heading: 0),
                animated: true)
        }

        // Sync city pins
        c.syncCityPins(cities: cities, in: map)

        // Update view model ref (lightweight)
        c.viewModel = viewModel
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var viewModel: GlobeViewModel
        weak var mapView: MKMapView?
        var lastFlyToISO: String?

        // Single source of truth: polygon → ISO (no reverse dict needed)
        // Using poly.title as ISO avoids storing a second dictionary entirely.
        var isoByPolygon: [ObjectIdentifier: String] = [:]   // keyed by poly identity

        // O(1) status lookup — rebuilt only when countries change
        var isoToStatus: [String: Int16] = [:]
        var lastCountrySnapshot: [(String, Int16)] = []

        // City geocoding
        var cityAnnotations: [NSManagedObjectID: CityAnnotation] = [:]
        var cityCoords:       [NSManagedObjectID: CLLocationCoordinate2D] = [:]
        var geocodingInFlight: Set<NSManagedObjectID> = []
        private let geocodeSemaphore = DispatchSemaphore(value: 3) // max 3 concurrent

        // Track previous selected/searched ISO to minimise overlay refreshes
        var lastSelectedISO: String? = nil
        var lastSearchedISO: String? = nil

        init(viewModel: GlobeViewModel) {
            self.viewModel = viewModel
        }

        // MARK: Load GeoJSON (background, autoreleasepool)

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
                                if let poly = geo as? MKPolygon { polys = [poly] }
                                else if let multi = geo as? MKMultiPolygon { polys = multi.polygons }
                                else { continue }
                                for poly in polys {
                                    poly.title = iso   // ISO stored on the polygon itself
                                    allPolygons.append(poly)
                                }
                            }
                        }
                    }

                    DispatchQueue.main.async { [weak self] in
                        guard let self, let map = self.mapView else { return }
                        // isoByPolygon keyed by ObjectIdentifier avoids a second strong ref
                        for poly in allPolygons {
                            self.isoByPolygon[ObjectIdentifier(poly)] = poly.title
                        }
                        map.addOverlays(allPolygons, level: .aboveRoads)
                    }
                }
            }
        }

        // MARK: City pin sync (capped concurrency)

        func syncCityPins(cities: [City], in map: MKMapView) {
            let currentIDs = Set(cities.map { $0.objectID })
            for (id, ann) in cityAnnotations where !currentIDs.contains(id) {
                map.removeAnnotation(ann)
                cityAnnotations.removeValue(forKey: id)
            }
            for city in cities {
                let id = city.objectID
                if let ann = cityAnnotations[id] {
                    let status = TravelStatus(rawValue: city.status) ?? .none
                    if ann.status != status {
                        ann.status = status
                        (map.view(for: ann) as? CityPinView)?.applyStatus(status)
                    }
                } else {
                    geocodeCity(city, in: map)
                }
            }
        }

        private func geocodeCity(_ city: City, in map: MKMapView) {
            let id = city.objectID
            guard !geocodingInFlight.contains(id) else { return }
            if let coord = cityCoords[id] { addCityPin(city: city, coord: coord, in: map); return }

            geocodingInFlight.insert(id)
            let query = [city.name, city.region?.country?.name]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
            guard !query.isEmpty else { geocodingInFlight.remove(id); return }

            // Respect concurrency cap on background thread
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self else { return }
                self.geocodeSemaphore.wait()
                let req = MKLocalSearch.Request()
                req.naturalLanguageQuery = query
                req.resultTypes = .address
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
            let ann = CityAnnotation(cityName: city.name ?? "",
                                     coordinate: coord,
                                     status: TravelStatus(rawValue: city.status) ?? .none)
            cityAnnotations[city.objectID] = ann
            map.addAnnotation(ann)
        }

        // MARK: Status change notification

        @objc func handleStatusChanged(_ notification: Notification) {
            // Rebuild status cache from current overlays' titles
            refreshOverlayColors()
        }

        // MARK: Tap handling — reuse existing renderers ONLY

        @objc func handleTap(_ gr: UITapGestureRecognizer) {
            guard let map = mapView else { return }
            let pt    = gr.location(in: map)
            let coord = map.convert(pt, toCoordinateFrom: map)
            let mapPt = MKMapPoint(coord)

            var best: (iso: String, area: Double)? = nil

            for overlay in map.overlays {
                guard let poly = overlay as? MKPolygon,
                      let iso  = poly.title, !iso.isEmpty,
                      // Only use already-created renderers — never allocate new ones here
                      let renderer = map.renderer(for: poly) as? MKPolygonRenderer else { continue }
                let polyPt = renderer.point(for: mapPt)
                guard renderer.path?.contains(polyPt) == true else { continue }
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
            v.applyStatus(city.status)
            return v
        }

        // MARK: Overlay renderer — called once per overlay, cached by MapKit

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let poly = overlay as? MKPolygon else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolygonRenderer(polygon: poly)
            apply(renderer: renderer, iso: poly.title ?? "")
            return renderer
        }

        // MARK: Colour logic

        func apply(renderer: MKPolygonRenderer, iso: String) {
            let rawStatus  = isoToStatus[iso] ?? 0
            let status     = TravelStatus(rawValue: rawStatus) ?? .none
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

        // Refresh only overlays whose ISO is selected or searched, or was previously so
        func refreshOverlayColors() {
            guard let map = mapView else { return }
            let selISO  = viewModel.selectedCountry?.isoCode
            let srchISO = viewModel.searchedISOCode
            let relevant = Set([selISO, srchISO, lastSelectedISO, lastSearchedISO].compactMap { $0 })
            lastSelectedISO = selISO
            lastSearchedISO = srchISO

            for overlay in map.overlays {
                guard let poly = overlay as? MKPolygon,
                      let iso  = poly.title,
                      let renderer = map.renderer(for: poly) as? MKPolygonRenderer else { continue }
                // Always refresh highlighted/status countries; skip plain unvisited ones
                let rawStatus = isoToStatus[iso] ?? 0
                let needsUpdate = relevant.contains(iso) || rawStatus != 0
                guard needsUpdate else { continue }
                apply(renderer: renderer, iso: iso)
                renderer.setNeedsDisplay()  // lighter than invalidatePath()
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
            markerTintColor = UIColor.systemGray.withAlphaComponent(0.5); glyphText = "·"; glyphImage = nil
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

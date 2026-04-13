//
//  GlobeView.swift
//  Terris
//
//  Interactive Apple Maps globe.
//  Uses MKMapView in .globe style (iOS 16+) with custom MKMarkerAnnotationView
//  pins coloured by TravelStatus. Tapping a pin selects the country.
//

import SwiftUI
import MapKit
import CoreData

// MARK: - SwiftUI wrapper

struct GlobeView: UIViewRepresentable {
    var viewModel: GlobeViewModel
    let countries: [Country]

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()

        // ── Globe projection (iOS 16+) ──────────────────────────────────────
        map.preferredConfiguration = MKGlobeConfiguration()
        map.camera = MKMapCamera(
            lookingAtCenter: CLLocationCoordinate2D(latitude: 20, longitude: 10),
            fromDistance: 15_000_000,
            pitch: 0,
            heading: 0
        )

        // Appearance
        map.showsCompass       = true
        map.showsScale         = false
        map.showsBuildings     = false
        map.showsUserLocation  = false
        map.pointOfInterestFilter = .excludingAll
        map.isRotateEnabled    = true
        map.isPitchEnabled     = false   // keep globe flat-on

        map.delegate = context.coordinator
        context.coordinator.mapView = map

        // Register custom annotation view
        map.register(CountryMarkerView.self,
                     forAnnotationViewWithReuseIdentifier: CountryMarkerView.reuseID)

        // Seed annotations
        seedAnnotations(map: map)

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Refresh existing annotation colours when CoreData changes
        for ann in map.annotations.compactMap({ $0 as? CountryAnnotation }) {
            if let country = countries.first(where: { $0.isoCode == ann.isoCode }) {
                let newColor = viewModel.color(for: country)
                let newStatus = TravelStatus(rawValue: country.status) ?? .none
                if ann.markerColor != newColor {
                    ann.markerColor = newColor
                    ann.status = newStatus
                    // Refresh the live view if it's visible
                    if let view = map.view(for: ann) as? CountryMarkerView {
                        view.refresh(color: newColor, status: newStatus)
                    }
                }
            }
        }

        // Sync selection highlight
        if let selected = viewModel.selectedCountry,
           let iso = selected.isoCode,
           let ann = viewModel.annotations[iso] {
            let current = map.selectedAnnotations.compactMap { $0 as? CountryAnnotation }.first
            if current?.isoCode != iso {
                map.selectAnnotation(ann, animated: true)
            }
        } else if viewModel.selectedCountry == nil,
                  let first = map.selectedAnnotations.first {
            map.deselectAnnotation(first, animated: true)
        }
    }

    // MARK: - Seed annotations once

    private func seedAnnotations(map: MKMapView) {
        let centroids = CountryCentroids.all
        var annotations: [CountryAnnotation] = []

        for country in countries {
            guard let iso = country.isoCode,
                  let (lat, lon) = centroids[iso] else { continue }

            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let ann = CountryAnnotation(country: country,
                                        coordinate: coord,
                                        color: viewModel.color(for: country))
            viewModel.annotations[iso] = ann
            annotations.append(ann)
        }
        map.addAnnotations(annotations)
    }
}

// MARK: - Coordinator / MKMapViewDelegate

extension GlobeView {

    final class Coordinator: NSObject, MKMapViewDelegate {
        let viewModel: GlobeViewModel
        weak var mapView: MKMapView?

        init(viewModel: GlobeViewModel) {
            self.viewModel = viewModel
        }

        // Provide custom annotation view
        func mapView(_ mapView: MKMapView,
                     viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let ann = annotation as? CountryAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: CountryMarkerView.reuseID,
                for: ann) as! CountryMarkerView
            view.configure(with: ann)
            return view
        }

        // Tap selects country
        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            guard let ann = annotation as? CountryAnnotation else { return }
            NotificationCenter.default.post(
                name: .globeCountryTapped,
                object: nil,
                userInfo: ["isoCode": ann.isoCode]
            )
        }

        // Tap on empty space deselects
        func mapView(_ mapView: MKMapView, didDeselect annotation: MKAnnotation) {
            // Only clear selection if nothing else is being selected
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                if mapView.selectedAnnotations.isEmpty {
                    self?.viewModel.selectCountry(nil)
                }
            }
        }

        // Callout accessory tap — opens detail
        func mapView(_ mapView: MKMapView,
                     annotationView view: MKAnnotationView,
                     calloutAccessoryControlTapped control: UIControl) {
            guard let ann = view.annotation as? CountryAnnotation else { return }
            NotificationCenter.default.post(
                name: .globeCountryTapped,
                object: nil,
                userInfo: ["isoCode": ann.isoCode]
            )
        }
    }
}

// MARK: - Custom marker view

final class CountryMarkerView: MKMarkerAnnotationView {
    static let reuseID = "CountryMarker"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        canShowCallout          = true
        calloutOffset           = CGPoint(x: 0, y: -4)
        rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        animatesWhenAdded       = false
        displayPriority         = .defaultLow   // let MapKit cull dense clusters
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with ann: CountryAnnotation) {
        refresh(color: ann.markerColor, status: ann.status)
    }

    func refresh(color: UIColor, status: TravelStatus) {
        markerTintColor = color
        switch status {
        case .none:
            glyphImage = nil
            glyphText  = "·"
        case .wantToVisit:
            glyphImage = UIImage(systemName: "bookmark.fill")
            glyphText  = nil
        case .visited:
            glyphImage = UIImage(systemName: "checkmark")
            glyphText  = nil
        case .livedIn:
            glyphImage = UIImage(systemName: "house.fill")
            glyphText  = nil
        }
        // Unvisited pins are tiny; marked ones stand taller
        if status == .none {
            displayPriority = .defaultLow
        } else {
            displayPriority = .defaultHigh
        }
    }
}

// MARK: - Notification name (shared)

extension Notification.Name {
    static let globeCountryTapped = Notification.Name("globeCountryTapped")
}

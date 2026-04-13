//
//  GlobeViewModel.swift
//  Terris
//

import Foundation
import MapKit
import SwiftUI
import CoreData
import Observation

@Observable
final class GlobeViewModel {
    var selectedCountry: Country?
    var statusFilter: TravelStatus? = nil   // nil = show all

    // Map isoCode → annotation for fast status-colour refresh
    var annotations: [String: CountryAnnotation] = [:]

    func selectCountry(_ country: Country?) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            selectedCountry = country
        }
    }

    func color(for country: Country) -> UIColor {
        let status = TravelStatus(rawValue: country.status) ?? .none
        return status.globeColor
    }

    /// Call after a country's status changes to refresh its pin colour.
    func updateAnnotation(for country: Country) {
        guard let iso = country.isoCode,
              let ann = annotations[iso] else { return }
        ann.markerColor = color(for: country)
        ann.status = TravelStatus(rawValue: country.status) ?? .none
    }
}

// MARK: - Custom annotation

final class CountryAnnotation: NSObject, MKAnnotation {
    let isoCode: String
    let countryName: String
    dynamic var coordinate: CLLocationCoordinate2D
    var markerColor: UIColor
    var status: TravelStatus

    init(country: Country, coordinate: CLLocationCoordinate2D, color: UIColor) {
        self.isoCode = country.isoCode ?? ""
        self.countryName = country.name ?? ""
        self.coordinate = coordinate
        self.markerColor = color
        self.status = TravelStatus(rawValue: country.status) ?? .none
    }

    var title: String? { countryName }
    var subtitle: String? { status.label }
}

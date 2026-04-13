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

    func selectCountry(_ country: Country?) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            selectedCountry = country
        }
    }

    func color(for country: Country) -> Color {
        let status = TravelStatus(rawValue: country.status) ?? .none
        return status.color
    }
}


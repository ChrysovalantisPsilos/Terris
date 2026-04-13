//
//  GlobeViewModel.swift
//  Terris
//

import Foundation
import SwiftUI
import CoreData
import Observation

@Observable
final class GlobeViewModel {
    var selectedCountry: Country?
    var statusFilter: TravelStatus? = nil   // nil = show all
    var searchedISOCode: String? = nil      // ISO code highlighted via search

    func selectCountry(_ country: Country?) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            selectedCountry = country
        }
    }
}

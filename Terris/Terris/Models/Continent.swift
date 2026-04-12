//
//  Continent.swift
//  Terris
//

import SwiftUI

enum Continent: String, CaseIterable, Identifiable {
    case africa        = "Africa"
    case antarctica    = "Antarctica"
    case asia          = "Asia"
    case europe        = "Europe"
    case northAmerica  = "North America"
    case oceania       = "Oceania"
    case southAmerica  = "South America"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .africa:       return "🌍"
        case .antarctica:   return "🧊"
        case .asia:         return "🌏"
        case .europe:       return "🌍"
        case .northAmerica: return "🌎"
        case .oceania:      return "🌏"
        case .southAmerica: return "🌎"
        }
    }

    var color: Color {
        switch self {
        case .africa:       return .orange
        case .antarctica:   return .cyan
        case .asia:         return .red
        case .europe:       return .blue
        case .northAmerica: return .green
        case .oceania:      return .purple
        case .southAmerica: return .yellow
        }
    }

    var totalCountries: Int {
        switch self {
        case .africa:       return 54
        case .antarctica:   return 0
        case .asia:         return 48
        case .europe:       return 44
        case .northAmerica: return 23
        case .oceania:      return 14
        case .southAmerica: return 12
        }
    }
}

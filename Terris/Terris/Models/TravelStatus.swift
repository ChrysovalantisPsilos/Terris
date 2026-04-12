//
//  TravelStatus.swift
//  Terris
//

import SwiftUI

enum TravelStatus: Int16, CaseIterable, Identifiable {
    case none       = 0
    case wantToVisit = 1
    case visited    = 2
    case livedIn    = 3

    var id: Int16 { rawValue }

    var label: String {
        switch self {
        case .none:        return "Not Visited"
        case .wantToVisit: return "Want to Visit"
        case .visited:     return "Visited"
        case .livedIn:     return "Lived In"
        }
    }

    var icon: String {
        switch self {
        case .none:        return "circle"
        case .wantToVisit: return "bookmark.fill"
        case .visited:     return "checkmark.circle.fill"
        case .livedIn:     return "house.fill"
        }
    }

    var color: Color {
        switch self {
        case .none:        return Color(.systemGray5)
        case .wantToVisit: return Color(red: 0.655, green: 0.545, blue: 0.980) // lavender #A78BFA
        case .visited:     return Color(red: 0.306, green: 0.804, blue: 0.769) // teal #4ECDC4
        case .livedIn:     return Color(red: 1.0,   green: 0.820, blue: 0.400) // gold #FFD166
        }
    }

    var globeColor: UIColor {
        switch self {
        case .none:        return UIColor.systemGray.withAlphaComponent(0.25)
        case .wantToVisit: return UIColor(red: 0.655, green: 0.545, blue: 0.980, alpha: 0.75)
        case .visited:     return UIColor(red: 0.306, green: 0.804, blue: 0.769, alpha: 0.85)
        case .livedIn:     return UIColor(red: 1.0,   green: 0.820, blue: 0.400, alpha: 0.90)
        }
    }
}

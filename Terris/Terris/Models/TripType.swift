//
//  TripType.swift
//  Terris
//

import Foundation

enum TripType: String, CaseIterable, Identifiable {
    case solo       = "Solo"
    case couple     = "Couple"
    case family     = "Family"
    case business   = "Business"
    case group      = "Group"
    case backpacking = "Backpacking"
    case luxury     = "Luxury"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .solo:        return "person.fill"
        case .couple:      return "person.2.fill"
        case .family:      return "figure.2.and.child.holdinghands"
        case .business:    return "briefcase.fill"
        case .group:       return "person.3.fill"
        case .backpacking: return "bag.fill"
        case .luxury:      return "crown.fill"
        }
    }
}

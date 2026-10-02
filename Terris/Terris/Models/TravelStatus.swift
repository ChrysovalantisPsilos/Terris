//
//  TravelStatus.swift
//  Terris
//
//  Stored as Int16 on Country.status. Colours live in Theme.color(for:).
//

import SwiftUI

enum TravelStatus: Int16, CaseIterable, Identifiable, Sendable {
    case none        = 0
    case wantToVisit = 1
    case visited     = 2
    case livedIn     = 3

    var id: Int16 { rawValue }

    /// The statuses a user can pick, in the order the picker shows them.
    static let pickable: [TravelStatus] = [.visited, .livedIn, .wantToVisit]

    var label: LocalizedStringKey {
        switch self {
        case .none: "Not visited"
        case .wantToVisit: "Want to go"
        case .visited: "Visited"
        case .livedIn: "Lived"
        }
    }
}

//
//  AppRouter.swift
//  Terris
//
//  App-wide navigation state: which country page is open, and whether the
//  photo import is showing. Any screen can open a country.
//

import SwiftUI
import Observation

struct OpenCountry: Identifiable, Equatable {
    let iso: String
    var id: String { iso }
}

@MainActor
@Observable
final class AppRouter {
    var country: OpenCountry?
    var showingImport = false

    func open(_ iso: String) { country = OpenCountry(iso: iso) }
}

/// The Map tab's layout. The user switches it from the map's toolbar; the
/// choice is remembered.
enum MapLayout: String, CaseIterable, Identifiable {
    case globe, journal, atlas

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .globe: "Globe"
        case .journal: "Journal"
        case .atlas: "Atlas"
        }
    }

    var systemImage: String {
        switch self {
        case .globe: "globe.europe.africa"
        case .journal: "list.bullet.rectangle"
        case .atlas: "map"
        }
    }
}

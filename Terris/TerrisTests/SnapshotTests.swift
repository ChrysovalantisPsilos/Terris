//
//  SnapshotTests.swift
//  TerrisTests
//
//  Pictures of every screen, light and dark, with a fake footprint, at an
//  iPhone 17's size: "<name>-<light|dark>.png". Each PNG is attached to the
//  test and, when SNAPSHOT_DIR is set (CI passes TEST_RUNNER_SNAPSHOT_DIR),
//  written there for the workflow's artifact. Nothing is compared: these are
//  for looking at. CI runs them only on a run by hand with "snapshots".
//

import SwiftUI
import XCTest
import CoreData
@testable import Terris

@MainActor
final class SnapshotTests: XCTestCase {
    private static let size = CGSize(width: 402, height: 874)

    override func setUp() async throws {
        UserDefaults.standard.set(true, forKey: "hasOnboarded")
        UserDefaults.standard.set(true, forKey: "hasSeenTour")
    }

    // MARK: Map

    func testMapSnapshots() async throws {
        let fixture = Fixture.full()
        for layout in MapLayout.allCases {
            UserDefaults.standard.set(layout.rawValue, forKey: "mapLayout")
            for dark in [false, true] {
                try await shot(fixture.dress(RootView()), name: "map-\(layout.rawValue)", dark: dark)
            }
        }
        UserDefaults.standard.set(MapLayout.globe.rawValue, forKey: "mapLayout")
    }

    func testEmptyMapSnapshots() async throws {
        let fixture = Fixture.empty()
        for layout in MapLayout.allCases {
            UserDefaults.standard.set(layout.rawValue, forKey: "mapLayout")
            try await shot(fixture.dress(RootView()), name: "map-\(layout.rawValue)-empty", dark: false)
        }
        UserDefaults.standard.set(MapLayout.globe.rawValue, forKey: "mapLayout")
    }

    // MARK: Country, flights, search

    func testCountrySnapshots() async throws {
        let fixture = Fixture.full()
        for dark in [false, true] {
            try await shot(fixture.dress(CountryScreen(iso: "JP", store: fixture.store)), name: "country-japan", dark: dark)
        }
        // Never been: no dates, still the facts.
        try await shot(fixture.dress(CountryScreen(iso: "FI", store: fixture.store)), name: "country-unvisited", dark: false)
    }

    func testFlightsSnapshots() async throws {
        let fixture = Fixture.full()
        for dark in [false, true] {
            try await shot(fixture.dress(FlightsScreen()), name: "flights", dark: dark)
        }
        try await shot(Fixture.empty().dress(FlightsScreen()), name: "flights-empty", dark: false)
    }

    func testFlightFormSnapshots() async throws {
        let fixture = Fixture.full()
        try await shot(fixture.dress(FlightFormScreen(draft: .new(now: Fixture.base), store: fixture.store)),
                       name: "flight-add", dark: false)
        var draft = FlightDraft.new(now: Fixture.base)
        draft.from = kAirportDatabase.first { $0.iata == "BRU" }
        draft.to = kAirportDatabase.first { $0.iata == "ATH" }
        draft.arrival = Fixture.base.addingTimeInterval(3 * 3600 + 15 * 60)
        draft.airline = "Aegean"
        draft.number = "A3 621"
        draft.seat = "12A"
        draft.rating = 4
        for dark in [false, true] {
            try await shot(fixture.dress(FlightFormScreen(draft: draft, store: fixture.store)),
                           name: "flight-add-filled", dark: dark)
        }
    }

    func testFlightDetailSnapshots() async throws {
        let fixture = Fixture.full()
        let id = try XCTUnwrap(fixture.store.flightRecords().first { $0.from == "BRU" && $0.to == "ATH" }?.id)
        for dark in [false, true] {
            try await shot(fixture.dress(FlightScreen(id: id, store: fixture.store)), name: "flight-detail", dark: dark)
        }
    }

    func testSearchSnapshots() async throws {
        let fixture = Fixture.full()
        try await shot(fixture.dress(SearchScreen()), name: "search", dark: false)
    }

    // MARK: Guide

    func testTourSnapshots() async throws {
        let fixture = Fixture.empty()
        for card in TourCard.allCases {
            try await shot(fixture.dress(TourScreen(startingAt: card)), name: "tour-\(card.rawValue + 1)", dark: false)
        }
        try await shot(fixture.dress(TourScreen()), name: "tour-1", dark: true)
    }

    func testGuideSnapshots() async throws {
        let fixture = Fixture.empty()
        for dark in [false, true] {
            try await shot(fixture.dress(GuideScreen()), name: "guide", dark: dark)
        }
    }

    // MARK: Scan and launch

    func testScanSnapshots() async throws {
        let fixture = Fixture.empty()
        try await shot(fixture.dress(ScanScreen()), name: "scan-intro", dark: false)
        try await shot(fixture.dress(ScanScreen(model: ScanModel(phase: .scanning, tally: Fixture.tally(found: 22, of: 0.6)))),
                       name: "scan-progress", dark: false)
        try await shot(fixture.dress(ScanScreen(model: ScanModel(phase: .scanning, tally: Fixture.tally(found: 22, of: 0.6)))),
                       name: "scan-progress", dark: true)
        try await shot(fixture.dress(ScanScreen(model: ScanModel(phase: .done, tally: Fixture.tally(found: 34, of: 1)))),
                       name: "scan-done", dark: false)
        try await shot(fixture.dress(ScanScreen(model: ScanModel(phase: .denied))), name: "scan-denied", dark: false)
    }

    func testLaunchSnapshots() async throws {
        for dark in [false, true] {
            try await shot(LaunchScreenView().environment(\.motionEnabled, false), name: "launch", dark: dark, settle: 1.2)
        }
    }

    // MARK: Rendering

    // MARK: iPad (for the App Store's iPad screenshots)

    /// An iPad Pro 12.9"/13" screen in points, with regular size classes so
    /// the app lays out as it does on iPad (sidebar, wider sheets).
    private static let iPadSize = CGSize(width: 1024, height: 1366)

    func testIPadSnapshots() async throws {
        let fixture = Fixture.full()
        UserDefaults.standard.set(MapLayout.globe.rawValue, forKey: "mapLayout")
        for dark in [false, true] {
            try await shot(fixture.dress(RootView()), name: "ipad-map", dark: dark, size: Self.iPadSize, regular: true)
        }
        try await shot(fixture.dress(CountryScreen(iso: "JP", store: fixture.store)), name: "ipad-country", dark: false,
                       size: Self.iPadSize, regular: true)
        try await shot(fixture.dress(FlightsScreen()), name: "ipad-flights", dark: false,
                       size: Self.iPadSize, regular: true)
    }

    private func shot<V: View>(_ view: V, name: String, dark: Bool, settle: TimeInterval = 1.0,
                               size: CGSize? = nil, regular: Bool = false) async throws {
        let host = UIHostingController(rootView: view.tint(Theme.accent))
        host.overrideUserInterfaceStyle = dark ? .dark : .light
        if regular {
            host.traitOverrides.horizontalSizeClass = .regular
            host.traitOverrides.verticalSizeClass = .regular
        }
        // A window in the host app's scene, so it is really on screen and
        // drawHierarchy has something to draw.
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow(frame: .zero)
        window.frame = CGRect(origin: .zero, size: size ?? Self.size)
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        // Let SwiftUI lay out and the screens' tasks load their figures.
        try await Task.sleep(for: .seconds(settle))
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { context in
            if !window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) {
                window.layer.render(in: context.cgContext)
            }
        }
        let fullName = "\(name)-\(dark ? "dark" : "light")"
        let data = try XCTUnwrap(image.pngData())
        let attachment = XCTAttachment(image: image)
        attachment.name = fullName
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"], !dir.isEmpty {
            let folder = URL(fileURLWithPath: dir, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: folder.appendingPathComponent("\(fullName).png"))
        }
        host.dismiss(animated: false)
        window.isHidden = true
    }
}

// MARK: - Fake footprint (matches the design renders; never real data)

@MainActor
private struct Fixture {
    let persistence: PersistenceController
    let store: FootprintStore
    let router = AppRouter()

    func dress<V: View>(_ view: V) -> some View {
        view
            .environment(store)
            .environment(router)
            .environment(\.managedObjectContext, persistence.container.viewContext)
            // Final, still states: no fills, spins or reveals mid-flight.
            .environment(\.motionEnabled, false)
    }

    static func empty() -> Fixture {
        let persistence = PersistenceController(inMemory: true)
        return Fixture(persistence: persistence, store: FootprintStore(context: persistence.container.viewContext))
    }

    static let base = Date(timeIntervalSince1970: 1_700_000_000)
    static let lived = ["GR", "BE"]
    static let visited = ["FR", "IT", "ES", "PT", "DE", "NL", "AT", "CH", "CZ", "PL", "HR", "HU", "GB", "IE",
                          "IS", "NO", "SE", "DK", "TR", "CY", "EG", "MA", "AE", "JO", "TH", "JP", "SG", "ID",
                          "US", "CA", "MX", "PE", "AR", "AU"]
    static let wantTo = ["NZ", "BR", "CL", "IN", "VN", "KR", "ZA", "KE"]

    static func full() -> Fixture {
        let f = empty()
        let store = f.store
        let base = Fixture.base
        for (i, iso) in (lived + visited + wantTo).enumerated() {
            let status: TravelStatus = lived.contains(iso) ? .livedIn : wantTo.contains(iso) ? .wantToVisit : .visited
            store.setStatus(status, for: iso, now: base.addingTimeInterval(Double(i) * 86_400 * 9))
        }
        // The newest few, as on the renders' "Recently added".
        let recent = ["IS", "AE", "PE", "JO"]
        for (i, iso) in recent.enumerated() {
            store.setStatus(.none, for: iso)
            store.setStatus(.visited, for: iso, now: base.addingTimeInterval(Double(400 + i) * 86_400))
        }
        for city in ["Tokyo", "Kyoto", "Osaka", "Hakone"] { store.addCity(city, to: "JP") }
        for city in ["Athens", "Thessaloniki"] { store.addCity(city, to: "GR") }
        for city in ["Lima", "Cusco", "Arequipa"] { store.addCity(city, to: "PE") }
        for city in ["Brussels", "Ghent"] { store.addCity(city, to: "BE") }
        let day = 86_400.0
        store.setFirstVisit(Date(timeIntervalSince1970: 1_555_027_200), for: "JP")   // 12 Apr 2019
        store.setLastVisit(Date(timeIntervalSince1970: 1_730_592_000), for: "JP")    // 3 Nov 2024
        store.setNotes("Cherry blossom week in Kyoto. Take the early train to Hakone.", for: "JP")
        addFlights(f.persistence.container.viewContext, base: base, day: day)
        return f
    }

    private static func addFlights(_ ctx: NSManagedObjectContext, base: Date, day: Double) {
        func airport(_ code: String) -> Airport {
            let rec = kAirportDatabase.first { $0.iata == code }!
            let a = Airport(context: ctx)
            a.id = UUID(); a.iata = rec.iata; a.name = rec.name; a.city = rec.city
            a.countryISO = rec.countryISO; a.latitude = rec.lat; a.longitude = rec.lon
            return a
        }
        var airports: [String: Airport] = [:]
        func get(_ code: String) -> Airport {
            if let a = airports[code] { return a }
            let a = airport(code); airports[code] = a; return a
        }
        let flights: [(String, String, String, String, Double, Double)] = [
            ("ATH", "AMM", "Aegean", "A3 912", 1190, 1048),
            ("BRU", "ATH", "Aegean", "A3 621", 2090, 1000),
            ("ATH", "DXB", "Emirates", "EK 210", 2950, 860),
            ("BRU", "LHR", "British Airways", "BA 393", 350, 800),
            ("LIM", "EZE", "LATAM", "LA 2427", 3140, 650),
            ("MAD", "LIM", "Iberia", "IB 6651", 9480, 640),
        ]
        for (from, to, airline, number, km, offset) in flights {
            let f = Flight(context: ctx)
            f.id = UUID()
            f.departureAirport = get(from)
            f.arrivalAirport = get(to)
            f.airline = airline
            f.flightNumber = number
            f.distanceKm = km
            f.departureDate = base.addingTimeInterval(offset * day)
            if from == "BRU", to == "ATH" {
                f.arrivalDate = f.departureDate!.addingTimeInterval(3 * 3600 + 15 * 60)
                f.seatClass = "Economy"
                f.seatNumber = "12A"
                f.rating = 4
                f.notes = "Window seat over the Alps; landed early."
            }
        }
        try? ctx.save()
    }

    static func tally(found: Int, of fraction: Double) -> ScanTally {
        var t = ScanTally()
        t.total = 12_480
        let isos = Array((visited + lived).prefix(found))
        let processed = Int(Double(t.total) * fraction)
        for i in 0..<processed {
            if i % 4 == 0 {
                t.add(nil)
            } else {
                t.add(ScannedPhoto(id: "p\(i)", iso: isos[i % isos.count], date: nil))
            }
        }
        return t
    }
}

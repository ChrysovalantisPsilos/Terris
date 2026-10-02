//
//  CountrySilhouetteTests.swift
//  TerrisTests
//

import CoreGraphics
import Testing
@testable import Terris

@MainActor
struct CountrySilhouetteTests {
    func square(lon: Double, lat: Double, size: Double) -> [GeoPoint] {
        [GeoPoint(lon: lon, lat: lat), GeoPoint(lon: lon + size, lat: lat),
         GeoPoint(lon: lon + size, lat: lat + size), GeoPoint(lon: lon, lat: lat + size)]
    }

    @Test func fitsTheUnitSquareCentred() {
        let outline = CountrySilhouette.outline([square(lon: 10, lat: 0, size: 4)])
        let points = outline.flatMap { $0 }
        #expect(!points.isEmpty)
        #expect(points.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
        // Near the equator a square stays (almost) square and fills the unit square.
        #expect(abs((points.map(\.y).min() ?? 1) - 0) < 1e-9)
        #expect(abs((points.map(\.y).max() ?? 0) - 1) < 1e-9)
        #expect((points.map(\.x).max() ?? 0) > 0.99)
    }

    @Test func keepsTheAspectOfAWideCountry() {
        let wide = [GeoPoint(lon: 0, lat: 0), GeoPoint(lon: 8, lat: 0),
                    GeoPoint(lon: 8, lat: 2), GeoPoint(lon: 0, lat: 2)]
        let points = CountrySilhouette.outline([wide]).flatMap { $0 }
        let height = (points.map(\.y).max() ?? 0) - (points.map(\.y).min() ?? 0)
        #expect(abs(height - 0.25) < 1e-3)
        // Centred vertically.
        #expect(abs((points.map(\.y).min() ?? 0) - 0.375) < 1e-3)
    }

    @Test func dropsFarAwayIslandsButKeepsNearOnes() {
        let mainland = square(lon: 0, lat: 40, size: 8)
        let near = square(lon: 9, lat: 41, size: 1)       // just off the coast
        let far = square(lon: -55, lat: 3, size: 3)       // another continent
        let kept = CountrySilhouette.mainland([mainland, near, far])
        #expect(kept.count == 2)
        #expect(!kept.contains { $0 == far })
    }

    @Test func keepsAWholeIslandChain() {
        // Islands 2° apart, the last one 12° from the biggest: linked, so kept.
        let rings = [square(lon: 0, lat: 0, size: 5)] + (0..<4).map { square(lon: 7 + Double($0) * 3, lat: 1, size: 1) }
        #expect(CountrySilhouette.mainland(rings).count == 5)
    }

    @Test func emptyAndDegenerateInputDrawNothing() {
        #expect(CountrySilhouette.outline([]).isEmpty)
        #expect(CountrySilhouette.outline([[GeoPoint(lon: 1, lat: 1)]]).isEmpty)
    }

    @Test func areaPicksTheLargestRing() {
        #expect(CountrySilhouette.area(square(lon: 0, lat: 0, size: 2)) == 4)
        #expect(CountrySilhouette.area(square(lon: 0, lat: 0, size: 3)) == 9)
    }
}

//
//  ProjectionTests.swift
//  TerrisTests
//

import Testing
import CoreGraphics
@testable import Terris

@MainActor
struct ProjectionTests {
    @Test func globeCentreProjectsToOrigin() {
        let c = GeoPoint(lon: 15, lat: 30)
        let (p, visible) = Projection.orthographic(c, center: c)
        #expect(visible)
        #expect(abs(p.x) < 1e-9 && abs(p.y) < 1e-9)
    }

    @Test func antipodeIsHiddenAndPulledToTheLimb() {
        let (p, visible) = Projection.orthographic(GeoPoint(lon: -165, lat: -30),
                                                   center: GeoPoint(lon: 15, lat: 30))
        #expect(!visible)
        #expect(abs((p.x * p.x + p.y * p.y).squareRoot() - 1) < 1e-9 || (p.x == 0 && p.y == 0))
    }

    @Test func northIsUpOnTheGlobe() {
        let center = GeoPoint(lon: 0, lat: 0)
        #expect(Projection.orthographic(GeoPoint(lon: 0, lat: 45), center: center).point.y > 0)
        #expect(Projection.orthographic(GeoPoint(lon: 45, lat: 0), center: center).point.x > 0)
    }

    @Test(arguments: [GeoPoint(lon: 139.7, lat: 35.7), GeoPoint(lon: -58.4, lat: -34.6), GeoPoint(lon: 4.35, lat: 50.85)])
    func orthographicRoundTrips(_ p: GeoPoint) {
        let center = GeoPoint(lon: p.lon - 20, lat: p.lat / 2)
        let (q, visible) = Projection.orthographic(p, center: center)
        #expect(visible)
        let back = Projection.inverseOrthographic(q, center: center)!
        #expect(abs(back.lon - p.lon) < 1e-6)
        #expect(abs(back.lat - p.lat) < 1e-6)
    }

    @Test func offTheGlobeHasNoPoint() {
        #expect(Projection.inverseOrthographic(CGPoint(x: 0.9, y: 0.9), center: GeoPoint(lon: 0, lat: 0)) == nil)
    }

    @Test func equalEarthSpansMinusOneToOne() {
        #expect(abs(Projection.equalEarth(GeoPoint(lon: 180, lat: 0)).x - 1) < 1e-9)
        #expect(abs(Projection.equalEarth(GeoPoint(lon: -180, lat: 0)).x + 1) < 1e-9)
        #expect(Projection.equalEarth(GeoPoint(lon: 0, lat: 0)) == .zero)
        // The world is about half as tall as it is wide.
        #expect(Projection.equalEarthAspect > 0.45 && Projection.equalEarthAspect < 0.5)
    }

    @Test(arguments: [GeoPoint(lon: 139.7, lat: 35.7), GeoPoint(lon: -58.4, lat: -34.6), GeoPoint(lon: 0, lat: 0)])
    func flatMapInverseRoundTrips(_ p: GeoPoint) {
        let back = FlatMap.inverse(Projection.equalEarth(p))!
        #expect(abs(back.lon - p.lon) < 0.05)
        #expect(abs(back.lat - p.lat) < 0.05)
    }

    @Test func longitudesWrap() {
        #expect(Projection.normalizedLongitude(190) == -170)
        #expect(Projection.normalizedLongitude(-190) == 170)
        #expect(Projection.normalizedLongitude(45) == 45)
    }
}

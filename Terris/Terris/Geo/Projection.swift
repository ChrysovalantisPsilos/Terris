//
//  Projection.swift
//  Terris
//
//  Pure map projections in unit space, tested in ProjectionTests.
//  - Orthographic: the globe. Output in [-1, 1] (unit disc), y up.
//  - Equal Earth: the flat map. Output x in [-1, 1], y in [-ratio, ratio], y up.
//

import Foundation
import CoreGraphics

struct GeoPoint: Equatable, Sendable {
    var lon: Double
    var lat: Double
}

enum Projection {
    // MARK: Orthographic

    /// Projects onto a globe centred on `center`. Returns the unit-disc point
    /// and whether it's on the visible hemisphere. Hidden points are pulled
    /// onto the limb, so a partly hidden country is clipped at the horizon.
    static func orthographic(_ p: GeoPoint, center: GeoPoint) -> (point: CGPoint, visible: Bool) {
        let φ = p.lat * .pi / 180, λ = p.lon * .pi / 180
        let φ0 = center.lat * .pi / 180, λ0 = center.lon * .pi / 180
        let cosC = sin(φ0) * sin(φ) + cos(φ0) * cos(φ) * cos(λ - λ0)
        var x = cos(φ) * sin(λ - λ0)
        var y = cos(φ0) * sin(φ) - sin(φ0) * cos(φ) * cos(λ - λ0)
        let visible = cosC >= 0
        if !visible {
            let r = (x * x + y * y).squareRoot()
            if r > 0 { x /= r; y /= r }
        }
        return (CGPoint(x: x, y: y), visible)
    }

    /// The geographic point under a unit-disc point, or nil off the globe.
    static func inverseOrthographic(_ q: CGPoint, center: GeoPoint) -> GeoPoint? {
        let x = Double(q.x), y = Double(q.y)
        let ρ = (x * x + y * y).squareRoot()
        guard ρ <= 1 else { return nil }
        let φ0 = center.lat * .pi / 180, λ0 = center.lon * .pi / 180
        if ρ == 0 { return center }
        let c = asin(ρ)
        let φ = asin(cos(c) * sin(φ0) + y * sin(c) * cos(φ0) / ρ)
        let λ = λ0 + atan2(x * sin(c), ρ * cos(φ0) * cos(c) - y * sin(φ0) * sin(c))
        return GeoPoint(lon: normalizedLongitude(λ * 180 / .pi), lat: φ * 180 / .pi)
    }

    // MARK: Equal Earth

    private static let a1 = 1.340264, a2 = -0.081106, a3 = 0.000893, a4 = 0.003796
    private static let m = 3.0.squareRoot() / 2
    /// Raw x at lon 180, lat 0; used to scale x into [-1, 1].
    private static let xMax = equalEarthRaw(GeoPoint(lon: 180, lat: 0)).x
    /// Height / width of the projected world.
    static let equalEarthAspect = equalEarthRaw(GeoPoint(lon: 0, lat: 90)).y / xMax

    static func equalEarth(_ p: GeoPoint) -> CGPoint {
        let raw = equalEarthRaw(p)
        return CGPoint(x: raw.x / xMax, y: raw.y / xMax)
    }

    private static func equalEarthRaw(_ p: GeoPoint) -> CGPoint {
        let λ = p.lon * .pi / 180, φ = p.lat * .pi / 180
        let θ = asin(m * sin(φ))
        let θ2 = θ * θ, θ6 = θ2 * θ2 * θ2
        let x = 2 * 3.0.squareRoot() * λ * cos(θ)
            / (3 * (9 * a4 * θ6 * θ2 + 7 * a3 * θ6 + 3 * a2 * θ2 + a1))
        let y = θ * (a1 + a2 * θ2 + θ6 * (a3 + a4 * θ2))
        return CGPoint(x: x, y: y)
    }

    static func normalizedLongitude(_ lon: Double) -> Double {
        var l = lon.truncatingRemainder(dividingBy: 360)
        if l > 180 { l -= 360 }
        if l < -180 { l += 360 }
        return l
    }
}

//
//  Sky.swift
//  Terris
//
//  The backdrop behind the Map's globe and the Flights map: a daytime sky in
//  light mode, Night Atlas in dark (a deep navy gradient with faint stars).
//  The colours are Theme tokens; the stars are clear in light mode.
//

import SwiftUI

struct SkyBackdrop: View {
    /// Where the sky has faded into the canvas, as a share of the height.
    var fadeAt: Double = 0.8

    var body: some View {
        ZStack {
            LinearGradient(stops: [
                .init(color: Theme.skyTop, location: 0),
                .init(color: Theme.skyMid, location: fadeAt / 2),
                .init(color: Theme.canvas, location: fadeAt),
            ], startPoint: .top, endPoint: .bottom)
            Starfield()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Faint stars, placed the same way every time (dark mode only: the token is
/// clear in light mode).
struct Starfield: View {
    var count = 90

    var body: some View {
        Canvas { ctx, size in
            for star in Self.stars(count) {
                let r = star.size
                let rect = CGRect(x: star.x * size.width - r / 2, y: star.y * size.height * 0.75 - r / 2,
                                  width: r, height: r)
                var layer = ctx
                layer.opacity = star.brightness
                layer.fill(Path(ellipseIn: rect), with: .color(Theme.stars))
            }
        }
        .allowsHitTesting(false)
    }

    struct Star: Equatable {
        let x: Double, y: Double, size: CGFloat, brightness: Double
    }

    /// Deterministic positions (a small linear congruential generator), so
    /// snapshots and every launch look the same.
    static func stars(_ count: Int) -> [Star] {
        var seed: UInt64 = 0x5EED_7E44
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(1 << 31)
        }
        return (0..<count).map { _ in
            Star(x: next(), y: next(), size: 0.8 + 1.4 * next(), brightness: 0.35 + 0.65 * next())
        }
    }
}

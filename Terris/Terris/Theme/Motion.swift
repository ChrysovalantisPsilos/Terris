//
//  Motion.swift
//  Terris
//
//  Calm, native motion: short springs, ease curves, staggered reveals.
//  Everything here turns off when the user asks for Reduce Motion, and in
//  snapshot tests (`\.motionEnabled = false`), so pictures show final states.
//

import SwiftUI

enum Motion {
    static let spring = Animation.spring(response: 0.38, dampingFraction: 0.86)
    static let gentle = Animation.spring(response: 0.6, dampingFraction: 0.9)
    static let quick = Animation.spring(response: 0.25, dampingFraction: 0.9)

    static func easeOutCubic(_ t: Double) -> Double {
        let u = 1 - min(max(t, 0), 1)
        return 1 - u * u * u
    }

    static func easeInOutCubic(_ t: Double) -> Double {
        let t = min(max(t, 0), 1)
        return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }

    /// Delay for the n-th item of a staggered reveal, capped so long lists
    /// don't keep the last rows waiting.
    static func stagger(_ index: Int, step: Double = 0.035, cap: Double = 0.3) -> Double {
        min(Double(max(index, 0)) * step, cap)
    }
}

// MARK: - Switch

private struct MotionEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// False in snapshot tests: views render their final, still state.
    var motionEnabled: Bool {
        get { self[MotionEnabledKey.self] }
        set { self[MotionEnabledKey.self] = newValue }
    }
}

// MARK: - Reveal

/// Fades and lifts a view into place the first time it appears.
struct Reveal: ViewModifier {
    let index: Int
    @Environment(\.motionEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        let animate = enabled && !reduceMotion
        content
            .opacity(shown || !animate ? 1 : 0)
            .offset(y: shown || !animate ? 0 : 8)
            .onAppear {
                guard animate, !shown else { return }
                withAnimation(Motion.spring.delay(Motion.stagger(index))) { shown = true }
            }
    }
}

extension View {
    /// A one-time fade-and-lift on first appearance, staggered by index.
    func reveal(_ index: Int = 0) -> some View { modifier(Reveal(index: index)) }
}

// MARK: - Globe camera

/// Where the globe looks, with smooth turns (tap-to-centre, fling, intro
/// spin). Canvas can't interpolate a custom value, so the camera steps the
/// centre itself at display rate.
@MainActor
@Observable
final class GlobeCamera {
    var center: GeoPoint
    private var task: Task<Void, Never>?

    init(center: GeoPoint) { self.center = center }

    /// Jumps (a drag in progress).
    func set(_ point: GeoPoint) {
        task?.cancel()
        center = point
    }

    /// Turns to `target`, the short way round. Returns when it arrives (or is
    /// interrupted). With `animated` false it jumps.
    @discardableResult
    func turn(to target: GeoPoint, duration: Double, animated: Bool,
              curve: @escaping (Double) -> Double = Motion.easeInOutCubic) -> Task<Void, Never> {
        task?.cancel()
        guard animated, duration > 0 else {
            center = target
            return Task {}
        }
        let from = center
        let lonDelta = GlobeCamera.shortestDelta(from: from.lon, to: target.lon)
        let latDelta = target.lat - from.lat
        let start = ContinuousClock.now
        let task = Task { [weak self] in
            while !Task.isCancelled {
                let t = min((ContinuousClock.now - start) / .seconds(duration), 1)
                let k = curve(t)
                self?.center = GeoPoint(lon: Projection.normalizedLongitude(from.lon + lonDelta * k),
                                        lat: from.lat + latDelta * k)
                if t >= 1 { break }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
        self.task = task
        return task
    }

    /// Longitude change from a to b the short way (−180…180).
    nonisolated static func shortestDelta(from a: Double, to b: Double) -> Double {
        Projection.normalizedLongitude(b - a)
    }
}

// MARK: - Map effects

/// Time-based effects drawn by the map canvases: the countries filling in on
/// first show, pulses on countries that just changed, and route arcs drawing
/// themselves. Dates, not flags, so a TimelineView can work out each frame.
struct MapEffects: Equatable {
    var fillStart: Date? = nil
    var pulses: [String: Date] = [:]
    var routeStart: Date? = nil

    static let none = MapEffects()

    static let fillDuration = 1.1
    static let pulseDuration = 0.9
    static let routeDuration = 1.2

    /// Whether anything is still moving at `now` (the timeline can pause otherwise).
    func isActive(at now: Date) -> Bool {
        if let fillStart, now.timeIntervalSince(fillStart) < Self.fillDuration { return true }
        if let routeStart, now.timeIntervalSince(routeStart) < Self.routeDuration + 2.2 { return true }
        return pulses.values.contains { now.timeIntervalSince($0) < Self.pulseDuration }
    }

    /// 0…1 progress of the fill at `now` (1 when there's no fill running).
    func fillProgress(at now: Date) -> Double {
        guard let fillStart else { return 1 }
        return Motion.easeOutCubic(now.timeIntervalSince(fillStart) / Self.fillDuration)
    }

    /// 0…1 progress of the route drawing at `now`.
    func routeProgress(at now: Date) -> Double {
        guard let routeStart else { return 1 }
        return Motion.easeInOutCubic(now.timeIntervalSince(routeStart) / Self.routeDuration)
    }

    /// 0…1 phase of a pulse on `iso`, or nil when it isn't pulsing.
    func pulsePhase(_ iso: String, at now: Date) -> Double? {
        guard let start = pulses[iso] else { return nil }
        let t = now.timeIntervalSince(start) / Self.pulseDuration
        return (0..<1).contains(t) ? t : nil
    }

    /// Opacity of the k-th of n marked countries while the fill runs: each
    /// fades in over a short window, one after another.
    static func fillAlpha(index k: Int, count n: Int, progress: Double) -> Double {
        guard n > 0, progress < 1 else { return 1 }
        let window = 4.0
        let x = progress * (Double(n) + window) - Double(k)
        return min(max(x / window, 0), 1)
    }

    /// The ISOs whose status differs between two maps: new marks and changes
    /// (not removals, which have nothing left to pulse).
    static func changed(from old: [String: TravelStatus], to new: [String: TravelStatus]) -> [String] {
        new.compactMap { iso, status in old[iso] == status ? nil : iso }.sorted()
    }
}

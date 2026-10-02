//
//  MotionTests.swift
//  TerrisTests
//
//  The maths behind the animations: easing, stagger, the map effects' timing,
//  the globe camera's short way round, and the route arcs' overlap.
//

import Foundation
import CoreGraphics
import Testing
@testable import Terris

@MainActor
struct MotionTests {
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: Easing and stagger

    @Test func easingRunsZeroToOneAndClamps() {
        for ease in [Motion.easeOutCubic, Motion.easeInOutCubic] {
            #expect(ease(0) == 0)
            #expect(ease(1) == 1)
            #expect(ease(-0.5) == 0)
            #expect(ease(2) == 1)
            #expect(ease(0.3) < ease(0.6))
        }
        #expect(Motion.easeInOutCubic(0.5) == 0.5)
        #expect(Motion.easeOutCubic(0.5) > 0.5)
    }

    @Test func staggerStepsAndCaps() {
        #expect(Motion.stagger(0) == 0)
        #expect(abs(Motion.stagger(2) - 0.07) < 1e-9)
        #expect(Motion.stagger(100) == 0.3)
        #expect(Motion.stagger(-3) == 0)
    }

    // MARK: Map effects

    @Test func noEffectsAreStillAndComplete() {
        let e = MapEffects.none
        #expect(!e.isActive(at: t0))
        #expect(e.fillProgress(at: t0) == 1)
        #expect(e.routeProgress(at: t0) == 1)
        #expect(e.pulsePhase("FR", at: t0) == nil)
    }

    @Test func fillRunsThenSettles() {
        let e = MapEffects(fillStart: t0)
        #expect(e.isActive(at: t0))
        #expect(e.fillProgress(at: t0) == 0)
        let mid = e.fillProgress(at: t0.addingTimeInterval(MapEffects.fillDuration / 2))
        #expect(mid > 0 && mid < 1)
        #expect(e.fillProgress(at: t0.addingTimeInterval(MapEffects.fillDuration)) == 1)
        #expect(!e.isActive(at: t0.addingTimeInterval(MapEffects.fillDuration + 0.01)))
    }

    @Test func fillAlphaFadesCountriesInOneAfterAnother() {
        let n = 10
        #expect(MapEffects.fillAlpha(index: 0, count: n, progress: 0) == 0)
        #expect(MapEffects.fillAlpha(index: 9, count: n, progress: 0) == 0)
        // Mid-way, earlier countries are further in than later ones.
        let first = MapEffects.fillAlpha(index: 0, count: n, progress: 0.4)
        let last = MapEffects.fillAlpha(index: 9, count: n, progress: 0.4)
        #expect(first > last)
        // Done: everyone is fully in.
        for k in 0..<n { #expect(MapEffects.fillAlpha(index: k, count: n, progress: 1) == 1) }
        #expect(MapEffects.fillAlpha(index: 0, count: 0, progress: 0.2) == 1)
    }

    @Test func pulseHasAPhaseOnlyWhileRunning() {
        let e = MapEffects(pulses: ["JP": t0])
        #expect(e.pulsePhase("JP", at: t0) == 0)
        let half = e.pulsePhase("JP", at: t0.addingTimeInterval(MapEffects.pulseDuration / 2))
        #expect(half.map { abs($0 - 0.5) < 1e-4 } == true)
        #expect(e.pulsePhase("JP", at: t0.addingTimeInterval(MapEffects.pulseDuration + 0.01)) == nil)
        #expect(e.pulsePhase("FR", at: t0) == nil)
        #expect(e.isActive(at: t0.addingTimeInterval(0.1)))
        #expect(!e.isActive(at: t0.addingTimeInterval(MapEffects.pulseDuration + 0.01)))
    }

    @Test func routeStaysActiveForThePlane() {
        let e = MapEffects(routeStart: t0)
        #expect(e.routeProgress(at: t0) == 0)
        #expect(e.routeProgress(at: t0.addingTimeInterval(MapEffects.routeDuration)) == 1)
        // The plane glides after the arc draws, so the clock keeps going.
        #expect(e.isActive(at: t0.addingTimeInterval(FlatMap.planeDelay + FlatMap.planeDuration - 0.1)))
        #expect(!e.isActive(at: t0.addingTimeInterval(10)))
    }

    @Test func changedListsNewAndChangedMarksOnly() {
        let old: [String: TravelStatus] = ["FR": .visited, "JP": .wantToVisit, "GR": .livedIn]
        let new: [String: TravelStatus] = ["FR": .visited, "JP": .visited, "PE": .visited]
        #expect(MapEffects.changed(from: old, to: new) == ["JP", "PE"])
        #expect(MapEffects.changed(from: new, to: new).isEmpty)
    }

    // MARK: Globe

    @Test func cameraTurnsTheShortWayRound() {
        #expect(GlobeCamera.shortestDelta(from: 170, to: -170) == 20)
        #expect(GlobeCamera.shortestDelta(from: -170, to: 170) == -20)
        #expect(GlobeCamera.shortestDelta(from: 10, to: 40) == 30)
        #expect(GlobeCamera.shortestDelta(from: 0, to: 0) == 0)
    }

    @Test func cameraJumpsWhenNotAnimated() {
        let camera = GlobeCamera(center: GeoPoint(lon: 0, lat: 0))
        camera.turn(to: GeoPoint(lon: 120, lat: 30), duration: 1, animated: false)
        #expect(camera.center.lon == 120)
        #expect(camera.center.lat == 30)
    }

    @Test func draggingRotatesAndClampsLatitude() {
        let start = GeoPoint(lon: 0, lat: 0)
        let right = GlobeMap.rotated(start, by: CGSize(width: 100, height: 0), radius: 100)
        #expect(right.lon == -90)
        #expect(right.lat == 0)
        let far = GlobeMap.rotated(start, by: CGSize(width: 0, height: 1000), radius: 100)
        #expect(far.lat == 70)
        let wrap = GlobeMap.rotated(GeoPoint(lon: -170, lat: 0), by: CGSize(width: 40, height: 0), radius: 90)
        #expect(wrap.lon == 150)
    }

    // MARK: Routes

    @Test func arcsStartInTurnAndAllFinish() {
        #expect(FlatMap.arcShare(index: 0, count: 3, progress: 0) == 0)
        #expect(FlatMap.arcShare(index: 0, count: 3, progress: 0.3) > FlatMap.arcShare(index: 2, count: 3, progress: 0.3))
        #expect(FlatMap.arcShare(index: 2, count: 3, progress: 0.3) == 0)
        for i in 0..<3 { #expect(FlatMap.arcShare(index: i, count: 3, progress: 1) == 1) }
        #expect(FlatMap.arcShare(index: 0, count: 1, progress: 0.5) == 0.5)
    }
}

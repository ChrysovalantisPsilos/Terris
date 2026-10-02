//
//  ScanTallyTests.swift
//  TerrisTests
//

import Foundation
import Testing
@testable import Terris

@MainActor
struct ScanTallyTests {
    func photo(_ id: String, _ iso: String, day: Double?) -> ScannedPhoto {
        ScannedPhoto(id: id, iso: iso, date: day.map { Date(timeIntervalSince1970: $0 * 86_400) })
    }

    @Test func countsFoldIntoCountries() {
        var t = ScanTally()
        t.total = 5
        t.add(photo("a", "JP", day: 30))
        t.add(photo("b", "GR", day: 20))
        t.add(photo("c", "JP", day: 10))
        t.add(nil)            // no location
        t.addUnplaced()       // at sea
        #expect(t.processed == 5)
        #expect(t.withLocation == 4)
        #expect(t.foundOrder == ["JP", "GR"])
        #expect(t.fraction == 1)
        let jp = t.results.first!
        #expect(jp.iso == "JP" && jp.count == 2)
        #expect(jp.first == Date(timeIntervalSince1970: 10 * 86_400))
        #expect(jp.last == Date(timeIntervalSince1970: 30 * 86_400))
    }

    @Test func samplesKeepTheNewestFew() {
        var t = ScanTally()
        for i in 0..<20 { t.add(photo("p\(i)", "FR", day: Double(100 - i))) }
        #expect(t.results.first?.samples == (0..<ScanTally.sampleLimit).map { "p\($0)" })
    }

    @Test func undatedPhotosStillCount() {
        var t = ScanTally()
        t.add(photo("x", "PE", day: nil))
        #expect(t.results.first?.count == 1)
        #expect(t.results.first?.first == nil)
    }
}

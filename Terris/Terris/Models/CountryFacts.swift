//
//  CountryFacts.swift
//  Terris
//
//  Loads bundled, static fun facts keyed by ISO A2 country code. Offline,
//  free, trustworthy — no API, no hallucination. Shown on every country
//  detail page (visited or not) so the page is never a dead end.
//
//  countryFacts.json has three facts for every country in CountryData.all:
//  checked, timeless (no rankings or statistics that go stale) and neutral.
//  A country without an entry would simply show no facts section.
//

import Foundation

enum CountryFacts {
    private static let byISO: [String: [String]] = {
        guard let url = Bundle.main.url(forResource: "countryFacts", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return [:] }
        // Normalize keys to uppercase for case-insensitive lookup.
        var normalized: [String: [String]] = [:]
        for (k, v) in raw { normalized[k.uppercased()] = v }
        return normalized
    }()

    /// Fun facts for a country, or an empty array if none are bundled.
    static func facts(for isoCode: String?) -> [String] {
        guard let iso = isoCode?.uppercased(), !iso.isEmpty else { return [] }
        return byISO[iso] ?? []
    }
}

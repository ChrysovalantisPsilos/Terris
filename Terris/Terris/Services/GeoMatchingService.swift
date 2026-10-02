//
//  GeoMatchingService.swift
//  Terris
//

import Foundation
import CoreLocation
import MapKit
import CoreData

@MainActor
final class GeoMatchingService {
    static let shared = GeoMatchingService()

    struct GeoMatch {
        let countryName: String?
        let countryCode: String?
        let cityName: String?
        let administrativeArea: String?
    }

    /// Resolves a coordinate to a country entirely offline (point-in-polygon
    /// against bundled countries.geojson). No network, no rate limits — safe
    /// for bulk photo import. City-name enrichment is deferred; `cityName`
    /// is intentionally nil here (see plan: optional, cached, later).
    func match(latitude: Double, longitude: Double) async -> GeoMatch {
        guard let hit = OfflineCountryResolver.shared.resolve(latitude: latitude, longitude: longitude) else {
            return GeoMatch(countryName: nil, countryCode: nil, cityName: nil, administrativeArea: nil)
        }
        return GeoMatch(
            countryName: hit.name,
            countryCode: hit.iso,
            cityName: nil,
            administrativeArea: nil
        )
    }

    /// Find or create Country entity matching an ISO code
    func findOrCreateCountry(isoCode: String, name: String?, continent: String? = nil, in ctx: NSManagedObjectContext) -> Country {
        let req: NSFetchRequest<Country> = Country.fetchRequest()
        req.predicate = NSPredicate(format: "isoCode == %@", isoCode)
        req.fetchLimit = 1
        if let existing = try? ctx.fetch(req).first {
            return existing
        }
        let c = Country(context: ctx)
        c.id = UUID()
        c.isoCode = isoCode
        c.name = name ?? isoCode
        c.continent = continent ?? "Unknown"
        c.status = TravelStatus.none.rawValue
        return c
    }
}

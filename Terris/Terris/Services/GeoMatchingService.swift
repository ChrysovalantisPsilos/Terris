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

    func match(latitude: Double, longitude: Double) async -> GeoMatch {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return GeoMatch(countryName: nil, countryCode: nil, cityName: nil, administrativeArea: nil)
        }
        do {
            let items = try await request.mapItems
            guard let item = items.first,
                  let rep = item.addressRepresentations else {
                return GeoMatch(countryName: nil, countryCode: nil, cityName: nil, administrativeArea: nil)
            }
            return GeoMatch(
                countryName: rep.regionName,
                countryCode: rep.__regionCode,   // NS_REFINED_FOR_SWIFT — raw ObjC accessor
                cityName: rep.cityName,
                administrativeArea: rep.regionName
            )
        } catch {
            return GeoMatch(countryName: nil, countryCode: nil, cityName: nil, administrativeArea: nil)
        }
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

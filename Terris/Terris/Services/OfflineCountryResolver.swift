//
//  OfflineCountryResolver.swift
//  Terris
//
//  Resolves a coordinate → ISO country code entirely offline, using the
//  bundled countries.geojson (Natural Earth). Replaces the network
//  reverse-geocoder for bulk photo import: no rate limits, no latency,
//  works on thousands of coordinates.
//
//  Point-in-polygon is done with ray casting in projected MKMapPoint space,
//  so it needs no MKMapView / renderer (unlike the globe's tap hit-test).
//

import Foundation
import MapKit

// Safe off the main actor: loading is guarded by `lock`, and entries are
// read-only once loaded. The photo scan resolves on a background task.
nonisolated final class OfflineCountryResolver: @unchecked Sendable {
    static let shared = OfflineCountryResolver()

    struct Entry {
        let iso: String
        let name: String
        let polygon: MKPolygon
        let area: Double            // bounding-rect area, for overseas-territory tie-break
    }

    private var entries: [Entry] = []
    private var loaded = false
    private let lock = NSLock()

    /// Natural Earth marks some countries with ISO_A2 == "-99"; map by name.
    private static let nameToISO: [String: String] = [
        "France": "FR", "Norway": "NO", "Kosovo": "XK",
        "Northern Cyprus": "CY", "Somaliland": "SO"
    ]

    private func loadIfNeeded() {
        lock.lock(); defer { lock.unlock() }
        guard !loaded else { return }
        loaded = true

        guard let url = Bundle.main.url(forResource: "countries", withExtension: "geojson"),
              let data = try? Data(contentsOf: url),
              let features = try? MKGeoJSONDecoder().decode(data) else { return }

        var result: [Entry] = []
        for item in features {
            guard let feature = item as? MKGeoJSONFeature,
                  let propData = feature.properties,
                  let props = try? JSONSerialization.jsonObject(with: propData) as? [String: Any]
            else { continue }

            let name = props["name"] as? String ?? ""
            var iso = props["ISO_A2"] as? String ?? ""
            if iso == "-99" || iso.isEmpty {
                guard let mapped = Self.nameToISO[name] else { continue }
                iso = mapped
            }

            for geo in feature.geometry {
                let polys: [MKPolygon]
                if let poly = geo as? MKPolygon { polys = [poly] }
                else if let multi = geo as? MKMultiPolygon { polys = multi.polygons }
                else { continue }

                for poly in polys {
                    let rect = poly.boundingMapRect
                    result.append(Entry(iso: iso, name: name, polygon: poly,
                                        area: rect.width * rect.height))
                }
            }
        }
        entries = result
    }

    /// Returns (isoCode, countryName) for a coordinate, or nil if it falls in
    /// the ocean / outside all polygons. When a point is inside multiple
    /// polygons (overseas territories overlapping a mainland bounding box),
    /// the largest-area match wins — same rule the globe tap-test uses.
    func resolve(latitude: Double, longitude: Double) -> (iso: String, name: String)? {
        loadIfNeeded()
        let point = MKMapPoint(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))

        var best: Entry?
        for entry in entries {
            guard entry.polygon.boundingMapRect.contains(point) else { continue }
            guard Self.polygon(entry.polygon, contains: point) else { continue }
            if best == nil || entry.area > best!.area { best = entry }
        }
        guard let best else { return nil }
        return (best.iso, best.name)
    }

    // MARK: - Ray casting in MKMapPoint space (handles interior holes)

    private static func polygon(_ polygon: MKPolygon, contains point: MKMapPoint) -> Bool {
        guard ringContains(polygon.points(), polygon.pointCount, point) else { return false }
        // A hit inside a hole means the point is NOT in the polygon.
        if let interiors = polygon.interiorPolygons {
            for hole in interiors where ringContains(hole.points(), hole.pointCount, point) {
                return false
            }
        }
        return true
    }

    private static func ringContains(_ pts: UnsafeMutablePointer<MKMapPoint>,
                                     _ count: Int,
                                     _ p: MKMapPoint) -> Bool {
        guard count > 2 else { return false }
        var inside = false
        var j = count - 1
        for i in 0..<count {
            let pi = pts[i], pj = pts[j]
            if ((pi.y > p.y) != (pj.y > p.y)),
               p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y) + pi.x {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
}

//
//  WorldShapes.swift
//  Terris
//
//  Country outlines from the bundled countries.geojson, keyed by ISO A2.
//  Natural Earth marks a few countries "-99"; those are matched by name.
//  Countries too small for the dataset (Singapore, Malta…) have no shape and
//  are drawn as a dot at their centroid instead.
//

import Foundation

struct CountryShape: Sendable {
    let iso: String
    /// Outer rings and holes, each a closed list of points.
    let rings: [[GeoPoint]]
    let centroid: GeoPoint
}

final class WorldShapes: Sendable {
    static let shared = WorldShapes(resource: "countries")

    let shapes: [CountryShape]
    let byISO: [String: CountryShape]

    static let nameToISO: [String: String] = [
        "France": "FR", "Norway": "NO", "Kosovo": "XK",
        "Northern Cyprus": "CY", "Somaliland": "SO", "Taiwan": "TW"
    ]

    convenience init(resource: String, bundle: Bundle = .main) {
        let data = bundle.url(forResource: resource, withExtension: "geojson")
            .flatMap { try? Data(contentsOf: $0) } ?? Data()
        self.init(data: data)
    }

    init(data: Data) {
        var merged: [String: [[GeoPoint]]] = [:]
        if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let features = root["features"] as? [[String: Any]] {
            for feature in features {
                guard let props = feature["properties"] as? [String: Any],
                      let geometry = feature["geometry"] as? [String: Any],
                      let iso = Self.iso(from: props) else { continue }
                merged[iso, default: []] += Self.rings(from: geometry)
            }
        }
        let built = merged.map { iso, rings in
            CountryShape(iso: iso, rings: rings,
                         centroid: Self.centroid(iso: iso, rings: rings))
        }
        shapes = built.sorted { $0.iso < $1.iso }
        byISO = Dictionary(uniqueKeysWithValues: built.map { ($0.iso, $0) })
    }

    /// Where a country sits, for dots and for turning the globe to it.
    func centroid(of iso: String) -> GeoPoint? {
        if let shape = byISO[iso] { return shape.centroid }
        if let (lat, lon) = CountryCentroids.all[iso] { return GeoPoint(lon: lon, lat: lat) }
        return nil
    }

    // MARK: Parsing

    private static func iso(from props: [String: Any]) -> String? {
        let raw = (props["ISO_A2"] as? String) ?? ""
        if raw.count == 2, raw.allSatisfy(\.isLetter) { return raw.uppercased() }
        if let name = props["name"] as? String { return nameToISO[name] }
        return nil
    }

    private static func rings(from geometry: [String: Any]) -> [[GeoPoint]] {
        let type = geometry["type"] as? String
        let coords = geometry["coordinates"]
        let polygons: [[[[Double]]]]
        switch type {
        case "Polygon": polygons = [(coords as? [[[Double]]]) ?? []]
        case "MultiPolygon": polygons = (coords as? [[[[Double]]]]) ?? []
        default: polygons = []
        }
        return polygons.flatMap { polygon in
            polygon.map { ring in
                ring.compactMap { pair in
                    pair.count >= 2 ? GeoPoint(lon: pair[0], lat: pair[1]) : nil
                }
            }
        }
    }

    private static func centroid(iso: String, rings: [[GeoPoint]]) -> GeoPoint {
        if let (lat, lon) = CountryCentroids.all[iso] { return GeoPoint(lon: lon, lat: lat) }
        // Fall back to the centre of the largest ring's bounding box.
        let largest = rings.max { $0.count < $1.count } ?? []
        let lons = largest.map(\.lon), lats = largest.map(\.lat)
        return GeoPoint(lon: ((lons.min() ?? 0) + (lons.max() ?? 0)) / 2,
                        lat: ((lats.min() ?? 0) + (lats.max() ?? 0)) / 2)
    }
}

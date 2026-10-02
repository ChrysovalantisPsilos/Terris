//
//  CountrySilhouette.swift
//  Terris
//
//  A country's outline fitted into a unit square, for the illustrated hero
//  on a country's page. Pure: rings in, normalised polygons out. Only the
//  main landmass and the islands linked to it are kept, so France isn't
//  shrunk to fit French Guiana or the US to fit Alaska and Hawaii.
//

import Foundation

enum CountrySilhouette {
    /// The outline in a unit square (0…1 on both axes, y down), centred and
    /// with its aspect kept. Empty when there's nothing to draw.
    static func outline(_ rings: [[GeoPoint]]) -> [[CGPoint]] {
        let kept = mainland(rings)
        guard !kept.isEmpty else { return [] }
        let lats = kept.flatMap { $0.map(\.lat) }
        let midLat = ((lats.min() ?? 0) + (lats.max() ?? 0)) / 2
        let k = cos(midLat * .pi / 180)
        // Equirectangular around the country's own latitude: true enough
        // for a picture of one country.
        let projected = kept.map { $0.map { CGPoint(x: $0.lon * k, y: -$0.lat) } }
        let all = projected.flatMap { $0 }
        let minX = all.map(\.x).min()!, maxX = all.map(\.x).max()!
        let minY = all.map(\.y).min()!, maxY = all.map(\.y).max()!
        let w = maxX - minX, h = maxY - minY
        let size = max(w, h)
        guard size > 0 else { return [] }
        let dx = (size - w) / 2, dy = (size - h) / 2
        return projected.map { ring in
            ring.map { CGPoint(x: ($0.x - minX + dx) / size, y: ($0.y - minY + dy) / size) }
        }
    }

    /// The largest ring and the rings linked to it: each kept ring is within
    /// `reach` degrees of another kept one, so island chains (Japan,
    /// Indonesia) stay whole while distant territories (Alaska, Svalbard,
    /// French Guiana) drop out.
    static func mainland(_ rings: [[GeoPoint]], reach: Double = 3) -> [[GeoPoint]] {
        let usable = rings.filter { $0.count >= 3 }
        guard let anchor = usable.indices.max(by: { area(usable[$0]) < area(usable[$1]) }) else { return [] }
        let boxes = usable.map(bounds)
        var kept: Set<Int> = [anchor]
        var frontier = [anchor]
        while let i = frontier.popLast() {
            let zone = boxes[i].insetBy(dx: -reach, dy: -reach)
            for j in usable.indices where !kept.contains(j) && zone.intersects(boxes[j]) {
                kept.insert(j)
                frontier.append(j)
            }
        }
        return usable.indices.filter(kept.contains).map { usable[$0] }
    }

    /// Bounds in degrees (x = longitude, y = latitude).
    static func bounds(_ ring: [GeoPoint]) -> CGRect {
        let lons = ring.map(\.lon), lats = ring.map(\.lat)
        let minLon = lons.min() ?? 0, minLat = lats.min() ?? 0
        return CGRect(x: minLon, y: minLat,
                      width: (lons.max() ?? 0) - minLon, height: (lats.max() ?? 0) - minLat)
    }

    /// Unsigned area in square degrees (shoelace), for picking the mainland.
    static func area(_ ring: [GeoPoint]) -> Double {
        guard ring.count >= 3 else { return 0 }
        var sum = 0.0
        for i in ring.indices {
            let p = ring[i], q = ring[(i + 1) % ring.count]
            sum += p.lon * q.lat - q.lon * p.lat
        }
        return abs(sum) / 2
    }
}

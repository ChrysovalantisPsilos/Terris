//
//  WorldMapViews.swift
//  Terris
//
//  The two map renderings, drawn with Canvas from WorldShapes:
//  - GlobeMap: orthographic globe; drag to spin, tap a country to open it.
//  - FlatMap: Equal Earth world map; tap a country to open it.
//  Both shade countries by status: visited and lived solid, want-to-go hatched.
//  Countries without a shape (too small for the dataset) are drawn as dots.
//

import SwiftUI

/// Shared painting for both maps.
private struct MapPainter {
    let statusByISO: [String: TravelStatus]
    let highlightISO: String?

    func paint(_ ctx: inout GraphicsContext, shapes: [CountryShape],
               project: (GeoPoint) -> (CGPoint, Bool)?) {
        for shape in shapes {
            var path = Path()
            var anyVisible = false
            for ring in shape.rings {
                var first = true
                for p in ring {
                    guard let projected = project(p) else { continue }
                    let (pt, visible) = projected
                    anyVisible = anyVisible || visible
                    if first { path.move(to: pt); first = false } else { path.addLine(to: pt) }
                }
                path.closeSubpath()
            }
            guard anyVisible else { continue }
            let status = statusByISO[shape.iso] ?? .none
            fill(&ctx, path: path, status: status)
            ctx.stroke(path, with: .color(Theme.border), lineWidth: 0.5)
            if shape.iso == highlightISO {
                ctx.stroke(path, with: .color(Theme.ink), lineWidth: 2)
            }
        }
        // Dots for marked countries the dataset has no outline for.
        for (iso, status) in statusByISO where status != .none && WorldShapes.shared.byISO[iso] == nil {
            guard let c = WorldShapes.shared.centroid(of: iso),
                  let projected = project(c), projected.1 else { continue }
            let pt = projected.0
            let dot = Path(ellipseIn: CGRect(x: pt.x - 4, y: pt.y - 4, width: 8, height: 8))
            ctx.fill(dot, with: .color(Theme.color(for: status)))
            ctx.stroke(dot, with: .color(Theme.border), lineWidth: 1)
        }
    }

    private func fill(_ ctx: inout GraphicsContext, path: Path, status: TravelStatus) {
        switch status {
        case .wantToVisit:
            ctx.fill(path, with: .color(Theme.wantToFill))
            var hatch = ctx
            hatch.clip(to: path)
            let r = path.boundingRect
            var lines = Path()
            var x = r.minX - r.height
            while x < r.maxX {
                lines.move(to: CGPoint(x: x, y: r.maxY))
                lines.addLine(to: CGPoint(x: x + r.height, y: r.minY))
                x += 5
            }
            hatch.stroke(lines, with: .color(Theme.wantTo), lineWidth: 1.6)
        default:
            ctx.fill(path, with: .color(Theme.color(for: status)))
        }
    }
}

// MARK: - Globe

struct GlobeMap: View {
    let statusByISO: [String: TravelStatus]
    @Binding var center: GeoPoint
    var highlightISO: String? = nil
    var interactive = true
    var onSelect: (String) -> Void = { _ in }

    @State private var dragStart: GeoPoint?

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2 * 0.96
            let mid = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            Canvas { ctx, _ in
                let disc = Path(ellipseIn: CGRect(x: mid.x - radius, y: mid.y - radius,
                                                  width: radius * 2, height: radius * 2))
                ctx.fill(disc, with: .color(Theme.ocean))
                drawGraticule(&ctx, mid: mid, radius: radius)
                MapPainter(statusByISO: statusByISO, highlightISO: highlightISO)
                    .paint(&ctx, shapes: WorldShapes.shared.shapes) { p in
                        let (q, visible) = Projection.orthographic(p, center: center)
                        return (CGPoint(x: mid.x + q.x * radius, y: mid.y - q.y * radius), visible)
                    }
                // Soft limb shading so it reads as a sphere.
                ctx.fill(disc, with: .radialGradient(
                    Gradient(colors: [.clear, .clear, .black.opacity(0.16)]),
                    center: CGPoint(x: mid.x - radius * 0.3, y: mid.y - radius * 0.35),
                    startRadius: 0, endRadius: radius * 1.35))
            }
            .contentShape(Rectangle())
            .gesture(drag(radius: radius), isEnabled: interactive)
            .onTapGesture { location in
                guard interactive else { return }
                let q = CGPoint(x: (location.x - mid.x) / radius, y: (mid.y - location.y) / radius)
                if let geoPoint = Projection.inverseOrthographic(q, center: center),
                   let iso = CountryHitTest.iso(at: geoPoint, statusByISO: statusByISO) {
                    onSelect(iso)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(Text("Globe"))
    }

    private func drag(radius: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let start = dragStart ?? center
                if dragStart == nil { dragStart = center }
                let degreesPerPoint = 90 / Double(radius)
                center = GeoPoint(
                    lon: Projection.normalizedLongitude(start.lon - Double(value.translation.width) * degreesPerPoint),
                    lat: min(max(start.lat + Double(value.translation.height) * degreesPerPoint, -70), 70))
            }
            .onEnded { _ in dragStart = nil }
    }

    private func drawGraticule(_ ctx: inout GraphicsContext, mid: CGPoint, radius: CGFloat) {
        var lines = Path()
        func add(_ points: [GeoPoint]) {
            var pen = false
            for p in points {
                let (q, visible) = Projection.orthographic(p, center: center)
                let pt = CGPoint(x: mid.x + q.x * radius, y: mid.y - q.y * radius)
                if visible {
                    if pen { lines.addLine(to: pt) } else { lines.move(to: pt); pen = true }
                } else { pen = false }
            }
        }
        for lon in stride(from: -180.0, to: 180, by: 30) {
            add(stride(from: -90.0, through: 90, by: 3).map { GeoPoint(lon: lon, lat: $0) })
        }
        for lat in stride(from: -60.0, through: 60, by: 30) {
            add(stride(from: -180.0, through: 180, by: 3).map { GeoPoint(lon: $0, lat: lat) })
        }
        ctx.stroke(lines, with: .color(Theme.graticule), lineWidth: 0.6)
    }
}

// MARK: - Flat map

struct FlatMap: View {
    let statusByISO: [String: TravelStatus]
    var highlightISO: String? = nil
    var onSelect: (String) -> Void = { _ in }

    /// Height / width of the drawn world (Equal Earth, without Antarctica's tail).
    static let aspect = Projection.equalEarthAspect * 0.9

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let scaleX = w / 2, scaleY = h / (2 * Self.aspect) * 0.9
            let scale = min(scaleX, scaleY)
            let mid = CGPoint(x: w / 2, y: h / 2 + scale * 0.06)
            Canvas { ctx, _ in
                ctx.fill(Path(CGRect(origin: .zero, size: geo.size)), with: .color(Theme.ocean))
                MapPainter(statusByISO: statusByISO, highlightISO: highlightISO)
                    .paint(&ctx, shapes: WorldShapes.shared.shapes.filter { $0.iso != "AQ" }) { p in
                        let q = Projection.equalEarth(p)
                        return (CGPoint(x: mid.x + q.x * scale, y: mid.y - q.y * scale), true)
                    }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                let q = CGPoint(x: (location.x - mid.x) / scale, y: (mid.y - location.y) / scale)
                if let p = Self.inverse(q),
                   let iso = CountryHitTest.iso(at: p, statusByISO: statusByISO) {
                    onSelect(iso)
                }
            }
        }
        .aspectRatio(1 / Self.aspect, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(Text("World map"))
    }

    /// Numeric inverse of Equal Earth (bisection on latitude); good to ~0.01°.
    static func inverse(_ q: CGPoint) -> GeoPoint? {
        var lo = -90.0, hi = 90.0
        for _ in 0..<40 {
            let midLat = (lo + hi) / 2
            if Projection.equalEarth(GeoPoint(lon: 0, lat: midLat)).y < q.y { lo = midLat } else { hi = midLat }
        }
        let lat = (lo + hi) / 2
        let edge = Projection.equalEarth(GeoPoint(lon: 180, lat: lat)).x
        guard edge > 0 else { return nil }
        let lon = Double(q.x / edge) * 180
        guard abs(lon) <= 180 else { return nil }
        return GeoPoint(lon: lon, lat: lat)
    }
}

// MARK: - Hit testing

enum CountryHitTest {
    /// The country under a point: its outline first, then the nearest dot
    /// of a small marked country within ~2°.
    static func iso(at p: GeoPoint, statusByISO: [String: TravelStatus]) -> String? {
        if let hit = OfflineCountryResolver.shared.resolve(latitude: p.lat, longitude: p.lon) {
            return hit.iso
        }
        let candidates = statusByISO.keys.filter { WorldShapes.shared.byISO[$0] == nil }
        return candidates
            .compactMap { iso -> (String, Double)? in
                guard let c = WorldShapes.shared.centroid(of: iso) else { return nil }
                let d = hypot(c.lon - p.lon, c.lat - p.lat)
                return d < 2 ? (iso, d) : nil
            }
            .min { $0.1 < $1.1 }?.0
    }
}

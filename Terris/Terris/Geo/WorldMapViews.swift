//
//  WorldMapViews.swift
//  Terris
//
//  The two map renderings, drawn with Canvas from WorldShapes:
//  - GlobeMap: orthographic globe; drag to spin (with a fling), tap a
//    country to open it.
//  - FlatMap: Equal Earth world map with flight routes; tap a country.
//  Animated effects (fill-in, pulses, routes drawing, the plane) are timed
//  by MapEffects and drawn per frame only while one is running.
//  Both shade countries by status: visited and lived solid, want-to-go hatched.
//  Countries without a shape (too small for the dataset) are drawn as dots.
//

import SwiftUI

/// Shared painting for both maps, including the animated effects.
private struct MapPainter {
    let statusByISO: [String: TravelStatus]
    let highlightISO: String?
    var effects: MapEffects = .none
    var now: Date = .distantFuture

    func paint(_ ctx: inout GraphicsContext, shapes: [CountryShape],
               project: (GeoPoint) -> (CGPoint, Bool)?) {
        let progress = effects.fillProgress(at: now)
        let order = progress < 1 ? MapPainter.fillOrder(statusByISO) : [:]
        var pulsing: [(Path, TravelStatus, Double)] = []

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
            ctx.fill(path, with: .color(Theme.land))
            if status != .none {
                var layer = ctx
                layer.opacity = MapEffects.fillAlpha(index: order[shape.iso] ?? 0, count: order.count,
                                                     progress: progress)
                fill(&layer, path: path, status: status)
            }
            ctx.stroke(path, with: .color(Theme.border), lineWidth: 0.5)
            if shape.iso == highlightISO {
                ctx.stroke(path, with: .color(Theme.ink), lineWidth: 2)
            }
            if let phase = effects.pulsePhase(shape.iso, at: now) {
                pulsing.append((path, status, phase))
            }
        }
        // Dots for marked countries the dataset has no outline for.
        for (iso, status) in statusByISO where status != .none && WorldShapes.shared.byISO[iso] == nil {
            guard let c = WorldShapes.shared.centroid(of: iso),
                  let projected = project(c), projected.1 else { continue }
            let pt = projected.0
            let dot = Path(ellipseIn: CGRect(x: pt.x - 4, y: pt.y - 4, width: 8, height: 8))
            var layer = ctx
            layer.opacity = MapEffects.fillAlpha(index: order[iso] ?? 0, count: order.count, progress: progress)
            layer.fill(dot, with: .color(Theme.color(for: status)))
            layer.stroke(dot, with: .color(Theme.border), lineWidth: 1)
            if let phase = effects.pulsePhase(iso, at: now) {
                pulsing.append((Path(ellipseIn: CGRect(x: pt.x - 6, y: pt.y - 6, width: 12, height: 12)),
                                status, phase))
            }
        }
        // A pulse: a ring of the status colour that widens and fades.
        for (path, status, phase) in pulsing {
            let color = status == .none ? Theme.accent : Theme.color(for: status)
            ctx.stroke(path, with: .color(color.opacity(0.9 * (1 - phase))),
                       style: StrokeStyle(lineWidth: 2 + 10 * phase, lineJoin: .round))
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

    /// Marked countries in fill order: west to east, so the fill sweeps
    /// across the map.
    static func fillOrder(_ statusByISO: [String: TravelStatus]) -> [String: Int] {
        let marked = statusByISO.filter { $0.value != .none }.keys
        let sorted = marked.sorted {
            (WorldShapes.shared.centroid(of: $0)?.lon ?? 0) < (WorldShapes.shared.centroid(of: $1)?.lon ?? 0)
        }
        var order: [String: Int] = [:]
        for (i, iso) in sorted.enumerated() { order[iso] = i }
        return order
    }
}

/// Ticks a TimelineView only while an effect is running; settles to paused
/// once the longest one is over, so an idle map costs nothing.
private struct EffectClock: ViewModifier {
    let effects: MapEffects
    @Binding var settled: Bool

    func body(content: Content) -> some View {
        content.task(id: effects) {
            guard effects.isActive(at: .now) else { settled = true; return }
            settled = false
            try? await Task.sleep(for: .seconds(max(MapEffects.fillDuration, MapEffects.pulseDuration,
                                                    MapEffects.routeDuration + 2.2) + 0.1))
            if !Task.isCancelled { settled = true }
        }
    }
}

// MARK: - Globe

struct GlobeMap: View {
    let statusByISO: [String: TravelStatus]
    @Binding var center: GeoPoint
    var highlightISO: String? = nil
    var interactive = true
    var effects: MapEffects = .none
    var onSelect: (String) -> Void = { _ in }
    /// Called when a drag ends, with where the fling would carry the globe.
    var onFling: ((GeoPoint) -> Void)? = nil

    @State private var dragStart: GeoPoint?
    @State private var settled = true

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2 * 0.96
            let mid = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            TimelineView(.animation(paused: settled)) { timeline in
                Canvas { ctx, _ in
                    let disc = Path(ellipseIn: CGRect(x: mid.x - radius, y: mid.y - radius,
                                                      width: radius * 2, height: radius * 2))
                    ctx.fill(disc, with: .color(Theme.ocean))
                    drawGraticule(&ctx, mid: mid, radius: radius)
                    MapPainter(statusByISO: statusByISO, highlightISO: highlightISO,
                               effects: effects, now: timeline.date)
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
            }
            .modifier(EffectClock(effects: effects, settled: $settled))
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
                center = Self.rotated(start, by: value.translation, radius: radius)
            }
            .onEnded { value in
                if let start = dragStart, let onFling {
                    onFling(Self.rotated(start, by: value.predictedEndTranslation, radius: radius))
                }
                dragStart = nil
            }
    }

    /// The centre after dragging by `translation` from `start`.
    static func rotated(_ start: GeoPoint, by translation: CGSize, radius: CGFloat) -> GeoPoint {
        let degreesPerPoint = 90 / Double(radius)
        return GeoPoint(
            lon: Projection.normalizedLongitude(start.lon - Double(translation.width) * degreesPerPoint),
            lat: min(max(start.lat + Double(translation.height) * degreesPerPoint, -70), 70))
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
    /// Flight routes, drawn as great-circle arcs.
    var routes: [FlightFigures.Route] = []
    /// A route a small plane glides along once (the flight page).
    var planeRoute: FlightFigures.Route? = nil
    var effects: MapEffects = .none
    var onSelect: (String) -> Void = { _ in }

    @State private var settled = true

    /// Height / width of the drawn world (Equal Earth, without Antarctica's tail).
    static let aspect = Projection.equalEarthAspect * 0.9
    /// The plane waits for its arc to draw, then takes this long to cross.
    static let planeDelay = 0.5
    static let planeDuration = 2.0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let scaleX = w / 2, scaleY = h / (2 * Self.aspect) * 0.9
            let scale = min(scaleX, scaleY)
            let mid = CGPoint(x: w / 2, y: h / 2 + scale * 0.06)
            TimelineView(.animation(paused: settled)) { timeline in
                Canvas { ctx, _ in
                    ctx.fill(Path(CGRect(origin: .zero, size: geo.size)), with: .color(Theme.ocean))
                    MapPainter(statusByISO: statusByISO, highlightISO: highlightISO,
                               effects: effects, now: timeline.date)
                        .paint(&ctx, shapes: WorldShapes.shared.shapes.filter { $0.iso != "AQ" }) { p in
                            let q = Projection.equalEarth(p)
                            return (CGPoint(x: mid.x + q.x * scale, y: mid.y - q.y * scale), true)
                        }
                    drawRoutes(&ctx, mid: mid, scale: scale, now: timeline.date)
                } symbols: {
                    Image(systemName: "airplane")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .tag("plane")
                }
            }
            .modifier(EffectClock(effects: effects, settled: $settled))
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

    private func drawRoutes(_ ctx: inout GraphicsContext, mid: CGPoint, scale: CGFloat, now: Date) {
        let all = routes + (planeRoute.map { [$0] } ?? [])
        guard !all.isEmpty else { return }
        func screen(_ p: GeoPoint) -> CGPoint {
            let q = Projection.equalEarth(p)
            return CGPoint(x: mid.x + q.x * scale, y: mid.y - q.y * scale)
        }
        let progress = effects.routeProgress(at: now)
        var arcs = Path()
        var ends = Path()
        for (i, route) in all.enumerated() {
            // Each arc draws a little after the one before.
            let share = Self.arcShare(index: i, count: all.count, progress: progress)
            guard share > 0 else { continue }
            let points = Projection.greatCircle(from: route.from, to: route.to)
            let shown = Int((Double(points.count - 1) * share).rounded()) + 1
            var previous: GeoPoint?
            for p in points.prefix(shown) {
                // Lift the pen where the arc crosses the date line.
                if let prev = previous, abs(prev.lon - p.lon) < 180 {
                    arcs.addLine(to: screen(p))
                } else {
                    arcs.move(to: screen(p))
                }
                previous = p
            }
            for end in share >= 1 ? [route.from, route.to] : [route.from] {
                let pt = screen(end)
                ends.addEllipse(in: CGRect(x: pt.x - 2.5, y: pt.y - 2.5, width: 5, height: 5))
            }
        }
        ctx.stroke(arcs, with: .color(Theme.visited.opacity(0.85)), lineWidth: 1.4)
        ctx.fill(ends, with: .color(Theme.card))
        ctx.stroke(ends, with: .color(Theme.ink), lineWidth: 1)

        if let planeRoute, let plane = ctx.resolveSymbol(id: "plane") {
            let t = planeProgress(at: now)
            let points = Projection.greatCircle(from: planeRoute.from, to: planeRoute.to, steps: 96)
            let at = Double(points.count - 1) * t
            let i = min(Int(at), points.count - 2)
            let a = screen(points[i]), b = screen(points[i + 1])
            let f = CGFloat(at - Double(i))
            let pos = CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
            var layer = ctx
            layer.translateBy(x: pos.x, y: pos.y)
            // The SF Symbol points right (east); turn it along the arc.
            layer.rotate(by: .radians(Double(atan2(b.y - a.y, b.x - a.x))))
            layer.draw(plane, at: .zero)
        }
    }

    /// 0…1 along the flight-page route; 1 (at the destination) when still.
    private func planeProgress(at now: Date) -> Double {
        guard let start = effects.routeStart else { return 1 }
        let t = (now.timeIntervalSince(start) - Self.planeDelay) / Self.planeDuration
        return Motion.easeInOutCubic(t)
    }

    /// How much of the i-th of n arcs is drawn when the whole set is at
    /// `progress`: arcs start one after another and overlap.
    static func arcShare(index i: Int, count n: Int, progress: Double) -> Double {
        guard progress < 1, n > 1 else { return min(max(progress, 0), 1) }
        let span = 0.6
        let start = Double(i) / Double(n - 1) * (1 - span)
        return min(max((progress - start) / span, 0), 1)
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

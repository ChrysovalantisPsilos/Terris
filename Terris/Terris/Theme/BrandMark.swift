//
//  BrandMark.swift
//  Terris
//
//  The Summit Flag mark as SwiftUI shapes (geometry from
//  docs/brand/svg/mark-color.svg, viewBox 4 8.5 92 85.5), so each part can
//  animate on its own: the dome rises, its grid draws on, the pole grows, the
//  flag unfurls. Colours follow light and dark like the app icon.
//

import SwiftUI

/// Maps the mark's SVG viewBox into a rect, keeping its aspect.
private struct MarkSpace {
    static let box = CGRect(x: 4, y: 8.5, width: 92, height: 85.5)
    let scale: CGFloat
    let origin: CGPoint

    init(_ rect: CGRect) {
        scale = min(rect.width / Self.box.width, rect.height / Self.box.height)
        origin = CGPoint(x: rect.midX - Self.box.width * scale / 2 - Self.box.minX * scale,
                         y: rect.midY - Self.box.height * scale / 2 - Self.box.minY * scale)
    }

    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
    }
}

/// The hemisphere: centre (50, 90), radius 42, flat side down.
struct MarkDome: Shape {
    func path(in rect: CGRect) -> Path {
        let m = MarkSpace(rect)
        var path = Path()
        path.move(to: m.p(8, 90))
        path.addArc(center: m.p(50, 90), radius: 42 * m.scale,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// The globe grid on the dome: a latitude curve and a meridian ellipse.
struct MarkGrid: Shape {
    func path(in rect: CGRect) -> Path {
        let m = MarkSpace(rect)
        var path = Path()
        path.move(to: m.p(0, 70))
        path.addQuadCurve(to: m.p(100, 70), control: m.p(50, 60))
        path.addEllipse(in: CGRect(origin: m.p(32, 46), size: CGSize(width: 36 * m.scale, height: 88 * m.scale)))
        return path
    }
}

struct MarkPole: Shape {
    func path(in rect: CGRect) -> Path {
        let m = MarkSpace(rect)
        return Path(roundedRect: CGRect(origin: m.p(45.5, 14), size: CGSize(width: 7 * m.scale, height: 36 * m.scale)),
                    cornerRadius: 1.5 * m.scale)
    }
}

struct MarkFlag: Shape {
    func path(in rect: CGRect) -> Path {
        let m = MarkSpace(rect)
        var path = Path()
        path.move(to: m.p(52, 14))
        path.addLine(to: m.p(82, 23.5))
        path.addLine(to: m.p(52, 33))
        path.closeSubpath()
        return path
    }
}

/// The mark, drawn whole or mid-animation. `progress` runs 0…1 through the
/// four beats: dome (0–0.35), grid (0.25–0.6), pole (0.45–0.75), flag (0.65–1).
struct BrandMark: View {
    var progress: Double = 1

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            let m = MarkSpace(rect)
            let dome = beat(0, 0.35), grid = beat(0.25, 0.6), pole = beat(0.45, 0.75), flag = beat(0.65, 1)
            // Anchors, in unit space, for growing each part from its base.
            let base = UnitPoint(x: m.p(50, 90).x / max(rect.width, 1), y: m.p(50, 90).y / max(rect.height, 1))
            let poleBase = UnitPoint(x: m.p(49, 50).x / max(rect.width, 1), y: m.p(49, 50).y / max(rect.height, 1))
            let hoist = UnitPoint(x: m.p(52, 23.5).x / max(rect.width, 1), y: m.p(52, 23.5).y / max(rect.height, 1))
            ZStack {
                MarkDome()
                    .fill(Theme.lived)
                    .scaleEffect(x: 0.6 + 0.4 * dome, y: dome, anchor: base)
                    .opacity(dome)
                MarkGrid()
                    .trim(from: 0, to: grid)
                    .stroke(Theme.markGrid, style: StrokeStyle(lineWidth: 5 * m.scale, lineCap: .round))
                    .clipShape(MarkDome())
                MarkPole()
                    .fill(Theme.markPole)
                    .scaleEffect(x: 1, y: pole, anchor: poleBase)
                MarkFlag()
                    .fill(Theme.visited)
                    .overlay(MarkFlag().stroke(Theme.visited, style: StrokeStyle(lineWidth: 3 * m.scale, lineJoin: .round)))
                    .scaleEffect(x: flag, y: 0.7 + 0.3 * flag, anchor: hoist)
                    .rotationEffect(.degrees(-12 * (1 - flag)), anchor: hoist)
                    .opacity(flag > 0 ? 1 : 0)
            }
        }
        .aspectRatio(MarkSpace.box.width / MarkSpace.box.height, contentMode: .fit)
        .accessibilityHidden(true)
    }

    /// 0…1 for a beat running from `a` to `b` of the whole progress, eased.
    private func beat(_ a: Double, _ b: Double) -> Double {
        Motion.easeOutCubic((progress - a) / (b - a))
    }
}

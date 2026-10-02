//
//  CountryHero.swift
//  Terris
//
//  The picture across the top of a country's page, edge to edge: the newest
//  of the owner's own photos from there (read on the device, never uploaded),
//  or, without one, the country's outline in its status colour under the
//  Map's sky (Night Atlas in dark mode, where it glows). The name sits over a
//  soft shade that fades into the page; a small globe in the corner shows
//  where it is and pulses when the status changes.
//

import SwiftUI

struct CountryHero: View {
    let iso: String
    let name: String
    let subtitle: Text
    let status: TravelStatus
    /// The owner's photo to show, if any.
    let photoID: String?
    let effects: MapEffects

    @State private var photoFailed = false

    /// Includes the room the floating status picker overlaps at the bottom.
    static let height: CGFloat = 400

    private var showsPhoto: Bool { photoID != nil && !photoFailed }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if showsPhoto {
                AssetImage(assetIdentifier: photoID, targetSize: CGSize(width: 440, height: Self.height),
                           onUnavailable: { _ in photoFailed = true })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                LinearGradient(stops: [
                    .init(color: .clear, location: 0.35),
                    .init(color: Theme.photoScrim, location: 0.82),
                    .init(color: Theme.canvas, location: 1),
                ], startPoint: .top, endPoint: .bottom)
            } else {
                illustration
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 44, weight: .heavy))
                    .tracking(-0.8)
                    .lineLimit(2)
                    .minimumScaleFactor(0.55)
                subtitle
                    .font(.headline.weight(.medium))
                    .opacity(0.92)
            }
            .foregroundStyle(showsPhoto ? Theme.onPhoto : Theme.ink)
            .padding(.horizontal, Theme.margin)
            // Leaves room for the status picker that floats over the bottom.
            .padding(.bottom, 84)
        }
        .overlay(alignment: .topTrailing) { globe }
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// The outline under the sky, top right, clear of the name.
    private var illustration: some View {
        ZStack(alignment: .topTrailing) {
            SkyBackdrop(fadeAt: 1)
            if let shape = WorldShapes.shared.byISO[iso] {
                let outline = CountrySilhouette.outline(shape.rings)
                ZStack {
                    if let glow = Theme.glow(for: status) {
                        SilhouetteShape(polygons: outline)
                            .fill(glow, style: FillStyle(eoFill: true))
                            .blur(radius: 12)
                    }
                    SilhouetteShape(polygons: outline)
                        .fill(fill, style: FillStyle(eoFill: true))
                        .overlay(SilhouetteShape(polygons: outline)
                            .stroke(Theme.border, style: StrokeStyle(lineWidth: 1.2, lineJoin: .round)))
                }
                .frame(width: 200, height: 200)
                .padding(.top, 72)
                .padding(.trailing, 24)
            }
        }
        .accessibilityHidden(true)
    }

    private var fill: Color {
        status == .none ? Theme.outlineUnmarked : Theme.color(for: status)
    }

    private var globe: some View {
        Group {
            if let centroid = WorldShapes.shared.centroid(of: iso) {
                GlobeMap(statusByISO: [iso: status == .none ? .visited : status],
                         center: .constant(centroid), highlightISO: iso, interactive: false,
                         effects: effects)
                    .frame(width: 52, height: 52)
                    .background(Theme.card, in: Circle())
                    .overlay(Circle().stroke(Theme.card, lineWidth: 3))
                    .shadow(color: Theme.ink.opacity(0.15), radius: 6, y: 3)
                    .padding(.top, 18)
                    .padding(.trailing, Theme.margin)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// Polygons in a unit square, scaled to the shape's rect.
struct SilhouetteShape: Shape {
    let polygons: [[CGPoint]]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for ring in polygons {
            guard let first = ring.first else { continue }
            path.move(to: point(first, in: rect))
            for p in ring.dropFirst() { path.addLine(to: point(p, in: rect)) }
            path.closeSubpath()
        }
        return path
    }

    private func point(_ p: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + p.x * rect.width, y: rect.minY + p.y * rect.height)
    }
}

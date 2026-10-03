//
//  CountryHero.swift
//  Terris
//
//  The picture across the top of a country's page, edge to edge: the first
//  of the owner's own photos from there that opens (read on the device, never uploaded),
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
    /// The owner's photos from there, best first; the hero shows the first
    /// one that opens.
    let photoIDs: [String]
    let effects: MapEffects

    /// How many photos failed to open, so the hero moves on to the next.
    @State private var skipped = 0

    /// Includes the room the floating status picker overlaps at the bottom.
    static let height: CGFloat = 400

    private var photoID: String? { photoIDs.dropFirst(skipped).first }
    private var showsPhoto: Bool { photoID != nil }

    var body: some View {
        // A fixed-height frame with the picture behind it: a tall photo
        // filled into a ZStack would grow the stack past the frame and push
        // the name down under the status picker.
        Color.clear
            .frame(height: Self.height)
            .frame(maxWidth: .infinity)
            .background { picture }
            .overlay(alignment: .bottomLeading) { title }
            .overlay(alignment: .topTrailing) { globe }
            .clipped()
            .onChange(of: photoIDs) { skipped = 0 }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var picture: some View {
        if let photoID {
            AssetImage(assetIdentifier: photoID, targetSize: CGSize(width: 440, height: Self.height),
                       onUnavailable: { _ in skipped += 1 })
                .id(photoID)
                .overlay {
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0.3),
                        .init(color: Theme.photoScrim, location: 0.78),
                        .init(color: Theme.canvas, location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                }
        } else {
            illustration
        }
    }

    private var title: some View {
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
        .shadow(color: showsPhoto ? Theme.photoScrim : .clear, radius: 8)
        .padding(.horizontal, Theme.margin)
        // Leaves room for the status picker that floats over the bottom.
        .padding(.bottom, 84)
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

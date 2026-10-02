//
//  CountryHero.swift
//  Terris
//
//  The picture at the top of a country's page: the newest of the owner's own
//  photos from there (read on the device, never uploaded), or, without one,
//  the country's outline in its status colour. A small globe in the corner
//  shows where it is and pulses when the status changes.
//

import SwiftUI

struct CountryHero: View {
    let iso: String
    let name: String
    let subtitle: String
    let status: TravelStatus
    /// The owner's photo to show, if any.
    let photoID: String?
    let effects: MapEffects

    @State private var photoFailed = false

    static let height: CGFloat = 260

    private var showsPhoto: Bool { photoID != nil && !photoFailed }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if showsPhoto {
                AssetImage(assetIdentifier: photoID, targetSize: CGSize(width: 440, height: Self.height),
                           onUnavailable: { photoFailed = true })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                LinearGradient(colors: [.clear, Theme.photoScrim], startPoint: .center, endPoint: .bottom)
            } else {
                illustration
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.largeTitle.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .opacity(showsPhoto ? 0.9 : 1)
            }
            .foregroundStyle(showsPhoto ? Theme.onPhoto : Theme.ink)
            .padding(20)
        }
        .overlay(alignment: .topLeading) { globe }
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .clipShape(Theme.cardShape)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// The outline on a soft sea, top right, clear of the name.
    private var illustration: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: [Theme.ocean, Theme.canvas], startPoint: .top, endPoint: .bottom)
            if let shape = WorldShapes.shared.byISO[iso] {
                let outline = CountrySilhouette.outline(shape.rings)
                SilhouetteShape(polygons: outline)
                    .fill(fill, style: FillStyle(eoFill: true))
                    .overlay(SilhouetteShape(polygons: outline)
                        .stroke(Theme.border, style: StrokeStyle(lineWidth: 1.2, lineJoin: .round)))
                    .shadow(color: Theme.ink.opacity(0.12), radius: 10, y: 6)
                    .frame(width: 176, height: 176)
                    .padding(.top, 18)
                    .padding(.trailing, 22)
            }
        }
        .accessibilityHidden(true)
    }

    private var fill: Color {
        status == .none ? Theme.land : Theme.color(for: status)
    }

    private var globe: some View {
        Group {
            if let centroid = WorldShapes.shared.centroid(of: iso) {
                GlobeMap(statusByISO: [iso: status == .none ? .visited : status],
                         center: .constant(centroid), highlightISO: iso, interactive: false,
                         effects: effects)
                    .frame(width: 58, height: 58)
                    .background(Theme.card, in: Circle())
                    .overlay(Circle().stroke(Theme.card, lineWidth: 3))
                    .shadow(color: Theme.ink.opacity(0.15), radius: 6, y: 3)
                    .padding(14)
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

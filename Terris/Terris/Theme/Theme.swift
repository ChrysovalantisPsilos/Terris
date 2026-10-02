//
//  Theme.swift
//  Terris
//
//  Design tokens. Every colour on screen comes from here, in light and dark.
//  Glass is only for floating controls (see Glass.swift), never content cards.
//

import SwiftUI
import UIKit

enum Theme {
    // MARK: Surfaces and text

    static let canvas = dynamic(light: 0xF7F5F0, dark: 0x0F1418)
    static let card = dynamic(light: 0xFFFFFF, dark: 0x1A2127)
    static let subtle = dynamic(light: 0xEFEDE7, dark: 0x232B32)
    static let ink = dynamic(light: 0x17212B, dark: 0xEEF1F3)
    static let muted = dynamic(light: 0x6B7480, dark: 0x9AA4AE)

    // MARK: Map

    static let ocean = dynamic(light: 0xDCE6EA, dark: 0x12202A)
    static let land = dynamic(light: 0xE6E2D8, dark: 0x2A3238)
    static let border = dynamic(light: 0xFFFFFF, dark: 0x0F1418, lightAlpha: 0.7)
    static let graticule = dynamic(light: 0x9AAAB4, dark: 0x5B8BA8, lightAlpha: 0.35, darkAlpha: 0.32)

    // MARK: Sky (the Map's backdrop: a daytime sky in light, Night Atlas in dark)

    static let skyTop = dynamic(light: 0xC4D9E3, dark: 0x07131C)
    static let skyMid = dynamic(light: 0xDCE8EC, dark: 0x0C1A23)
    /// Secondary text and the accent figure set on the sky.
    static let skyInk = dynamic(light: 0x3E4A55, dark: 0xB9C4CC)
    static let skyAccent = dynamic(light: 0x9C331C, dark: 0xFF8A68)
    /// The soft light around the globe: white by day, an atmosphere by night.
    static let globeHalo = dynamic(light: 0xFFFFFF, dark: 0x3FB1C4, lightAlpha: 0.9, darkAlpha: 0.34)
    /// The shade at the globe's edge that makes it read as a sphere.
    static let limbShade = dynamic(light: 0x000000, dark: 0x03080C, lightAlpha: 0.16, darkAlpha: 0.5)
    /// Stars, dark only.
    static let stars = dynamic(light: 0xFFFFFF, dark: 0xDDEFF7, lightAlpha: 0, darkAlpha: 0.5)
    /// The glow under marked countries, dark only.
    static let visitedGlow = dynamic(light: 0xE8613C, dark: 0xFF7A55, lightAlpha: 0, darkAlpha: 0.65)
    static let livedGlow = dynamic(light: 0x1F7A8C, dark: 0x3FB1C4, lightAlpha: 0, darkAlpha: 0.65)
    /// Flight routes: coral by day, a glowing light line by night.
    static let route = dynamic(light: 0xE8613C, dark: 0xFFE3D6)
    static let routeGlow = dynamic(light: 0xE8613C, dark: 0xFF7A55, lightAlpha: 0.38, darkAlpha: 0.55)
    /// Airport dots at the ends of a route.
    static let airportDot = dynamic(light: 0xFFFFFF, dark: 0xFFFFFF)
    static let airportRing = dynamic(light: 0xE8613C, dark: 0x0F1418)

    // MARK: Status

    /// Visited — also the app's accent.
    static let visited = dynamic(light: 0xE8613C, dark: 0xFF7A55)
    static let lived = dynamic(light: 0x1F7A8C, dark: 0x3FB1C4)
    static let wantTo = dynamic(light: 0xF2B134, dark: 0xF2B134)
    /// Background under the want-to-go hatching.
    static let wantToFill = dynamic(light: 0xFBE9C2, dark: 0x3A3222)

    static let accent = visited

    /// A country you haven't marked, drawn on the hero's sky: visible on the
    /// night sky as well as the day one.
    static let outlineUnmarked = dynamic(light: 0xD5CEC0, dark: 0x5A6874)

    // Text and the shade under it on a photo (the country page's hero).
    static let onPhoto = dynamic(light: 0xFFFFFF, dark: 0xFFFFFF)
    static let photoScrim = dynamic(light: 0x0B0F12, dark: 0x0B0F12, lightAlpha: 0.62, darkAlpha: 0.7)

    // The Summit Flag's grid and pole (the mark, launch screen).
    static let markGrid = dynamic(light: 0x155A68, dark: 0x2A8394)
    static let markPole = dynamic(light: 0x17212B, dark: 0xF7F5F0)

    // MARK: Shape and motion

    static let cardRadius: CGFloat = 26
    /// Side margin for content.
    static let margin: CGFloat = 20
    static let cardShape = RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
    static let spring = Motion.spring

    // MARK: Type

    /// The "Terris" wordmark (Outfit Bold, bundled); everything else is the system font.
    static let wordmark = Font.custom("Outfit-Bold", size: 44, relativeTo: .largeTitle)

    // MARK: Helpers

    /// The night glow for a status (clear in light mode and for want to go).
    static func glow(for status: TravelStatus) -> Color? {
        switch status {
        case .visited: visitedGlow
        case .livedIn: livedGlow
        default: nil
        }
    }

    /// Text on a pill filled with a status colour.
    static func onStatus(_ status: TravelStatus) -> Color {
        status == .wantToVisit ? onWantTo : onPhoto
    }
    static let onWantTo = dynamic(light: 0x17212B, dark: 0x17212B)

    static func color(for status: TravelStatus) -> Color {
        switch status {
        case .none: land
        case .wantToVisit: wantTo
        case .visited: visited
        case .livedIn: lived
        }
    }

    private static func dynamic(light: UInt32, dark: UInt32,
                                lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

// MARK: - Card

extension View {
    /// A content card: solid surface, continuous corners. Never glass.
    func card(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: Theme.cardShape)
    }
}

/// A small caps-free section title with an optional trailing action.
struct SectionTitle<Trailing: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: LocalizedStringKey, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
            Spacer()
            trailing().font(.subheadline).foregroundStyle(Theme.accent)
        }
    }
}

//
//  Glass.swift
//  Terris
//
//  Liquid Glass for floating controls only: map overlays, floating buttons.
//  The tab bar gets it from the system TabView.
//

import SwiftUI

extension View {
    /// Glass panel for a floating overlay (e.g. the headline chip on the globe).
    func floatingGlass(cornerRadius: CGFloat = 24) -> some View {
        glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// A 48pt round glass button with an SF Symbol.
struct GlassIconButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel(Text(label))
    }
}

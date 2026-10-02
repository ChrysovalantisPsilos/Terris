//
//  LaunchScreenView.swift
//  Terris
//
//  The brief brand splash while the store loads: the Summit Flag lockup
//  rising onto the canvas.
//

import SwiftUI

struct LaunchScreenView: View {
    @State private var shown = false

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            Image(.brandLockup)
                .resizable()
                .scaledToFit()
                .frame(width: 180)
                .scaleEffect(shown ? 1 : 0.92)
                .offset(y: shown ? 0 : 12)
                .opacity(shown ? 1 : 0)
                .accessibilityLabel(Text("Terris"))
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { shown = true }
        }
    }
}

//
//  LaunchScreenView.swift
//  Terris
//
//  The brand splash while the store loads: the Summit Flag builds itself
//  (dome, grid, pole, flag), then "Terris" settles in underneath. Still,
//  and already complete, with Reduce Motion or in snapshots.
//

import SwiftUI

struct LaunchScreenView: View {
    @Environment(\.motionEnabled) private var motionEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: Double = 0
    @State private var wordmark = false

    /// How long the splash takes when animated, for the app to wait on.
    static let duration = 1.6

    var body: some View {
        let animate = motionEnabled && !reduceMotion
        ZStack {
            Theme.canvas.ignoresSafeArea()
            VStack(spacing: 14) {
                BrandMark(progress: animate ? progress : 1)
                    .frame(width: 120)
                Text(verbatim: "Terris")
                    .font(Theme.wordmark)
                    .tracking(-0.4)
                    .foregroundStyle(Theme.ink)
                    .opacity(wordmark || !animate ? 1 : 0)
                    .offset(y: wordmark || !animate ? 0 : 10)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "Terris"))
        }
        .task {
            guard animate else { return }
            let start = ContinuousClock.now
            let length = 1.1
            while progress < 1, !Task.isCancelled {
                progress = min((ContinuousClock.now - start) / .seconds(length), 1)
                try? await Task.sleep(for: .milliseconds(16))
            }
            withAnimation(Motion.gentle) { wordmark = true }
        }
    }
}

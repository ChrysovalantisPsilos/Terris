//
//  LaunchScreenView.swift
//  Terris
//
//  Animated splash screen shown while CoreData loads.
//

import SwiftUI

struct LaunchScreenView: View {
    @State private var globeScale: CGFloat = 0.6
    @State private var globeOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var ringScale: CGFloat = 0.5
    @State private var ringOpacity: Double = 0

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.07, blue: 0.15),
                         Color(red: 0.02, green: 0.04, blue: 0.10)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Globe icon + pulse rings
                ZStack {
                    // Outer pulse ring
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        .frame(width: 160, height: 160)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    // Inner pulse ring
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        .frame(width: 120, height: 120)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    // App icon / globe
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.2, green: 0.4, blue: 0.9),
                                             Color(red: 0.1, green: 0.2, blue: 0.6)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 90, height: 90)

                        Image(systemName: "globe.europe.africa.fill")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(globeScale)
                    .opacity(globeOpacity)
                    .shadow(color: Color(red: 0.2, green: 0.4, blue: 0.9).opacity(0.6), radius: 30)
                }

                // App name
                VStack(spacing: 6) {
                    Text("Terris")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Your world, mapped.")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .opacity(titleOpacity)
                .offset(y: titleOffset)
            }
        }
        .onAppear {
            // Globe pop-in
            withAnimation(.spring(response: 0.7, dampingFraction: 0.65).delay(0.1)) {
                globeScale = 1.0
                globeOpacity = 1.0
            }
            // Pulse rings expand
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                ringScale = 1.4
                ringOpacity = 1.0
            }
            withAnimation(.easeIn(duration: 0.5).delay(1.1)) {
                ringOpacity = 0
            }
            // Title slide up
            withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
                titleOpacity = 1.0
                titleOffset = 0
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}

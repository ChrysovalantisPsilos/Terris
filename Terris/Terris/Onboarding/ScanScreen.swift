//
//  ScanScreen.swift
//  Terris
//
//  "Find countries in my photos": on first launch, and from the Map's scan
//  button. Intro → (permission) → live scan with the globe filling in →
//  summary. Results are applied only when the user taps "Add to my map".
//

import SwiftUI
import UIKit

@MainActor
@Observable
final class ScanModel {
    enum Phase: Equatable {
        case intro
        case denied
        case scanning
        case done
    }

    private(set) var phase: Phase
    private(set) var tally: ScanTally
    private(set) var limited = false
    private var task: Task<Void, Never>?

    /// A preset phase and tally are for snapshots and previews.
    init(phase: Phase = .intro, tally: ScanTally = ScanTally()) {
        self.phase = phase
        self.tally = tally
    }

    var statusByISO: [String: TravelStatus] {
        Dictionary(uniqueKeysWithValues: tally.foundOrder.map { ($0, TravelStatus.visited) })
    }

    func start() async {
        var access = PhotoAccess.current
        if access == .notDetermined { access = await PhotoAccess.request() }
        guard access == .granted || access == .limited else { phase = .denied; return }
        limited = access == .limited
        phase = .scanning
        task = Task {
            for await update in PhotoScanner.scan() {
                withAnimation(Theme.spring) { tally = update }
            }
            if !Task.isCancelled { phase = .done }
        }
    }

    /// Stops early and keeps what was found so far.
    func stop() {
        task?.cancel()
        phase = .done
    }

    func cancel() { task?.cancel() }
}

struct ScanScreen: View {
    @Environment(FootprintStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var model: ScanModel
    @State private var center = GeoPoint(lon: 15, lat: 30)
    /// Called when the flow ends, whether the user added results or skipped.
    private let onFinish: () -> Void

    // A default argument can't build a main-actor model (defaults are
    // evaluated outside the main actor), so the fresh one is made here.
    init(model: ScanModel? = nil, onFinish: @escaping () -> Void = {}) {
        _model = State(initialValue: model ?? ScanModel())
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 20) {
            header
            GlobeMap(statusByISO: model.statusByISO, center: $center, interactive: model.phase != .scanning)
                .padding(.horizontal, 24)
                .frame(maxHeight: .infinity)
            footer
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Theme.canvas.ignoresSafeArea())
        .task(id: model.phase) {
            // Turn the globe slowly while scanning.
            guard model.phase == .scanning else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                center.lon = Projection.normalizedLongitude(center.lon + 0.25)
            }
        }
        .onDisappear { model.cancel() }
    }

    // MARK: Header

    @ViewBuilder
    private var header: some View {
        VStack(spacing: 8) {
            switch model.phase {
            case .intro:
                Text("See where you've been").font(.largeTitle.bold())
                Text("Terris reads where your photos were taken and fills in the countries for you. It all happens on this iPhone; your photos never leave it.")
                    .font(.subheadline).foregroundStyle(Theme.muted)
            case .denied:
                Text("Photos are off").font(.largeTitle.bold())
                Text("To find countries in your photos, allow Terris to read your photo library in Settings. Or skip and tap countries on the map yourself.")
                    .font(.subheadline).foregroundStyle(Theme.muted)
            case .scanning:
                Label("Scanning your photo library", systemImage: "sparkle")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                Text("Found ^[\(model.tally.foundOrder.count) country](inflect: true) so far…")
                    .font(.title.bold())
                    .contentTransition(.numericText(value: Double(model.tally.foundOrder.count)))
            case .done:
                Text("You've been to ^[\(model.tally.foundOrder.count) country](inflect: true)")
                    .font(.largeTitle.bold())
                Text("Found in \(model.tally.withLocation, format: .number) photos with a location.")
                    .font(.subheadline).foregroundStyle(Theme.muted)
            }
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 12) {
            switch model.phase {
            case .intro:
                primary("Find countries in my photos") { Task { await model.start() } }
                secondary("Skip, I'll add them myself") { finish() }
            case .denied:
                primary("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                secondary("Skip") { finish() }
            case .scanning:
                foundChips
                progressCard
                secondary("Stop and keep what's found") { model.stop() }
            case .done:
                foundChips
                if model.tally.foundOrder.isEmpty {
                    Text("No photos with a location were found. You can tap countries on the map instead.")
                        .font(.subheadline).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                    primary("Go to my map") { finish() }
                } else {
                    primary("Add to my map") {
                        store.applyScan(model.tally.results)
                        finish()
                    }
                    secondary("Not now") { finish() }
                }
            }
        }
    }

    private var foundChips: some View {
        let recent = model.tally.foundOrder.suffix(3).reversed()
        return HStack(spacing: 8) {
            ForEach(Array(recent), id: \.self) { iso in
                Text("\(Flag.emoji(for: iso)) \(store.entry(for: iso)?.name ?? iso)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Theme.card, in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(minHeight: 36)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(model.tally.processed, format: .number) of \(model.tally.total, format: .number) photos")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(model.tally.fraction, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline.monospacedDigit()).foregroundStyle(Theme.muted)
            }
            ProgressBar(fraction: model.tally.fraction)
            Label {
                Text("\(model.tally.withLocation, format: .number) with a location · analysed on this iPhone only")
            } icon: {
                Image(systemName: "lock")
            }
            .font(.caption).foregroundStyle(Theme.muted)
            if model.limited {
                Text("You allowed only some photos, so some countries may be missing.")
                    .font(.caption).foregroundStyle(Theme.muted)
            }
        }
        .foregroundStyle(Theme.ink)
        .card()
    }

    private func primary(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline).frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(Theme.accent)
    }

    private func secondary(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
        }
        .tint(Theme.ink)
    }

    private func finish() {
        model.cancel()
        onFinish()
        dismiss()
    }
}

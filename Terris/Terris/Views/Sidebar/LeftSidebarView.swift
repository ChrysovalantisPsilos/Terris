//
//  LeftSidebarView.swift
//  Terris
//

import SwiftUI
import CoreData

struct LeftSidebarView: View {
    var globeVM: GlobeViewModel
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Country.name, ascending: true)]
    ) private var allCountries: FetchedResults<Country>

    private var visitedCount: Int   { allCountries.filter { $0.status == TravelStatus.visited.rawValue }.count }
    private var livedInCount: Int   { allCountries.filter { $0.status == TravelStatus.livedIn.rawValue }.count }
    private var wantToCount: Int    { allCountries.filter { $0.status == TravelStatus.wantToVisit.rawValue }.count }
    private var totalCountries: Int { allCountries.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // App branding
                brandingHeader
                // Stats mini cards
                statsGrid
                // Status filter
                filterSection
                // Continent legend
                continentLegend
                // Quick list
                quickList
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Sections

    private var brandingHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "globe.europe.africa.fill")
                .font(.title)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan, .blue],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            VStack(alignment: .leading, spacing: 0) {
                Text("Terris")
                    .font(.title3.bold())
                Text("Your World, Explored")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 4)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatCard(value: visitedCount, label: "Visited", color: TravelStatus.visited.color,
                     icon: TravelStatus.visited.icon)
            StatCard(value: livedInCount, label: "Lived In", color: TravelStatus.livedIn.color,
                     icon: TravelStatus.livedIn.icon)
            StatCard(value: wantToCount, label: "Wishlist", color: TravelStatus.wantToVisit.color,
                     icon: TravelStatus.wantToVisit.icon)
            let pct = totalCountries > 0 ? Int((Double(visitedCount + livedInCount) / Double(totalCountries)) * 100) : 0
            StatCard(value: pct, label: "% Done", color: .orange, icon: "chart.pie.fill", suffix: "%")
        }
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Filter Globe")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                FilterButton(label: "All Countries", icon: "globe", isSelected: globeVM.statusFilter == nil) {
                    globeVM.statusFilter = nil
                }
                ForEach(TravelStatus.allCases.filter { $0 != .none }) { status in
                    FilterButton(label: status.label, icon: status.icon, color: status.color,
                                 isSelected: globeVM.statusFilter == status) {
                        globeVM.statusFilter = globeVM.statusFilter == status ? nil : status
                    }
                }
            }
        }
    }

    private var continentLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Continents")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(Continent.allCases) { continent in
                let countryCount = allCountries.filter { $0.continent == continent.rawValue }.count
                let doneCount   = allCountries.filter { $0.continent == continent.rawValue &&
                    ($0.status == TravelStatus.visited.rawValue || $0.status == TravelStatus.livedIn.rawValue)
                }.count
                HStack(spacing: 8) {
                    Circle()
                        .fill(continent.color)
                        .frame(width: 8, height: 8)
                    Text(continent.rawValue)
                        .font(.caption)
                    Spacer()
                    Text("\(doneCount)/\(countryCount)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var quickList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Visited Countries")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            let visited = allCountries.filter {
                $0.status == TravelStatus.visited.rawValue || $0.status == TravelStatus.livedIn.rawValue
            }
            if visited.isEmpty {
                Text("None yet — tap a country on the globe!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)
            } else {
                ForEach(visited.prefix(10), id: \.id) { country in
                    Button {
                        globeVM.selectCountry(country)
                    } label: {
                        HStack(spacing: 8) {
                            Text(flagEmoji(for: country.isoCode ?? ""))
                            Text(country.name ?? "")
                                .font(.caption.weight(.medium))
                            Spacer()
                            let s = TravelStatus(rawValue: country.status) ?? .none
                            Circle().fill(s.color).frame(width: 7, height: 7)
                        }
                    }
                    .buttonStyle(.plain)
                }
                if visited.count > 10 {
                    Text("+\(visited.count - 10) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func flagEmoji(for isoCode: String) -> String {
        guard isoCode.count == 2 else { return "🏳️" }
        let base: UInt32 = 127397
        var result = ""
        for scalar in isoCode.uppercased().unicodeScalars {
            guard let s = Unicode.Scalar(base + scalar.value) else { continue }
            result.append(Character(s))
        }
        return result.isEmpty ? "🏳️" : result
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let value: Int
    let label: String
    let color: Color
    let icon: String
    var suffix: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.subheadline)
            Text("\(value)\(suffix)")
                .font(.title3.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(color.opacity(0.2), lineWidth: 1))
        )
    }
}

struct FilterButton: View {
    let label: String
    let icon: String
    var color: Color = .primary
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(isSelected ? .white : color)
                    .font(.subheadline)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? .white : .primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? color : Color(.secondarySystemFill))
            )
        }
        .buttonStyle(.plain)
    }
}

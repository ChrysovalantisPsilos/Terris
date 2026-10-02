//
//  StatsDashboardView.swift
//  Terris
//

import SwiftUI
import CoreData
import Observation

@Observable
final class StatsViewModel {
    var visitedCount = 0
    var livedInCount = 0
    var wantToCount = 0
    var cityCount = 0
    var continentsCovered = 0
    var completionPercent: Double = 0
    var continentBreakdown: [ContinentStat] = []
    var totalCountries = 0
    var mostVisitedCountry: String? = nil

    struct ContinentStat: Identifiable {
        let id = UUID()
        let continent: String
        let visited: Int
        let total: Int
        var percent: Double { total > 0 ? Double(visited) / Double(total) : 0 }
        var color: Color { Continent.allCases.first { $0.rawValue == continent }?.color ?? .gray }
        var emoji: String {
            switch continent {
            case "Africa": return "🌍"
            case "Antarctica": return "🧊"
            case "Asia": return "🌏"
            case "Europe": return "🏰"
            case "North America": return "🗽"
            case "Oceania": return "🦘"
            case "South America": return "🌎"
            default: return "🌐"
            }
        }
    }

    func refresh(context: NSManagedObjectContext) {
        let countries = (try? context.fetch(Country.fetchRequest())) ?? []
        let cities = (try? context.fetch(City.fetchRequest())) ?? []

        visitedCount = countries.filter { $0.status == TravelStatus.visited.rawValue }.count
        livedInCount = countries.filter { $0.status == TravelStatus.livedIn.rawValue }.count
        wantToCount  = countries.filter { $0.status == TravelStatus.wantToVisit.rawValue }.count
        cityCount    = cities.filter { $0.status != TravelStatus.none.rawValue }.count
        totalCountries = countries.count

        let done = visitedCount + livedInCount
        completionPercent = totalCountries > 0 ? Double(done) / Double(totalCountries) : 0

        continentsCovered = Continent.allCases.filter { c in
            countries.contains { $0.continent == c.rawValue &&
                ($0.status == TravelStatus.visited.rawValue || $0.status == TravelStatus.livedIn.rawValue) }
        }.count

        continentBreakdown = Continent.allCases.compactMap { c in
            let all  = countries.filter { $0.continent == c.rawValue }
            let done = all.filter { $0.status == TravelStatus.visited.rawValue || $0.status == TravelStatus.livedIn.rawValue }
            return ContinentStat(continent: c.rawValue, visited: done.count, total: all.count)
        }
    }
}

struct StatsDashboardView: View {
    @State private var viewModel = StatsViewModel()
    @Environment(\.managedObjectContext) private var ctx

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroSection
                statGrid
                continentSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("My Stats")
        .navigationBarTitleDisplayMode(.large)
        .task { viewModel.refresh(context: ctx) }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange)) { _ in
            viewModel.refresh(context: ctx)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        HStack(spacing: 20) {
            // Completion ring
            ZStack {
                Circle()
                    .stroke(Color(.systemFill), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: viewModel.completionPercent)
                    .stroke(AngularGradient(colors: [.cyan, .blue, .purple], center: .center),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8), value: viewModel.completionPercent)
                VStack(spacing: 1) {
                    Text("\(Int(viewModel.completionPercent * 100))%")
                        .font(.title2.bold().monospacedDigit())
                    Text("World").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 10) {
                statLine(icon: "checkmark.circle.fill", color: TravelStatus.visited.color,
                         value: viewModel.visitedCount, label: "Countries visited")
                statLine(icon: "house.fill", color: TravelStatus.livedIn.color,
                         value: viewModel.livedInCount, label: "Countries lived in")
                statLine(icon: "bookmark.fill", color: TravelStatus.wantToVisit.color,
                         value: viewModel.wantToCount, label: "On wishlist")
            }
            Spacer()
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func statLine(icon: String, color: Color, value: Int, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color).font(.subheadline)
            Text("\(value)").font(.subheadline.bold().monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Stat grid

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            DashStatCard(value: viewModel.cityCount, label: "Cities Explored",
                     icon: "building.2.fill", color: .orange)
            DashStatCard(value: viewModel.continentsCovered, label: "Continents",
                     icon: "globe", color: .teal)
            DashStatCard(value: viewModel.visitedCount + viewModel.livedInCount,
                     label: "Total Countries", icon: "flag.fill", color: .blue)
        }
    }

    // MARK: - Continent section

    private var continentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Continent")
                .font(.headline)
                .padding(.horizontal, 2)

            ForEach(viewModel.continentBreakdown.filter { $0.total > 0 }) { stat in
                ContinentProgressCard(stat: stat)
            }
        }
    }
}

// MARK: - Stat card

struct DashStatCard: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.15)).frame(width: 42, height: 42)
                Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)").font(.title2.bold().monospacedDigit())
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }
}

// MARK: - Continent progress card

struct ContinentProgressCard: View {
    let stat: StatsViewModel.ContinentStat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(stat.emoji).font(.title3)
                Text(stat.continent).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(stat.visited) / \(stat.total)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemFill)).frame(height: 6)
                    Capsule()
                        .fill(stat.color)
                        .frame(width: geo.size.width * stat.percent, height: 6)
                        .animation(.spring(response: 0.6), value: stat.percent)
                }
            }
            .frame(height: 6)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }
}

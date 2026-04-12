//
//  StatsDashboardView.swift
//  Terris
//

import SwiftUI
import Charts
import CoreData
import Observation

@Observable
final class StatsViewModel {
    var visitedCount = 0
    var livedInCount = 0
    var wantToCount = 0
    var cityCount = 0
    var attractionCount = 0
    var continentsCovered = 0
    var completionPercent: Double = 0
    var continentBreakdown: [ContinentStat] = []
    var totalCountries = 0

    struct ContinentStat: Identifiable {
        let id = UUID()
        let continent: String
        let visited: Int
        let total: Int
        var color: Color {
            Continent.allCases.first { $0.rawValue == continent }?.color ?? .gray
        }
    }

    func refresh(context: NSManagedObjectContext) {
        let countryReq: NSFetchRequest<Country> = Country.fetchRequest()
        let cityReq: NSFetchRequest<City> = City.fetchRequest()
        let attrReq: NSFetchRequest<Attraction> = Attraction.fetchRequest()

        let countries = (try? context.fetch(countryReq)) ?? []
        let cities = (try? context.fetch(cityReq)) ?? []
        let attractions = (try? context.fetch(attrReq)) ?? []

        visitedCount = countries.filter { $0.status == TravelStatus.visited.rawValue }.count
        livedInCount = countries.filter { $0.status == TravelStatus.livedIn.rawValue }.count
        wantToCount  = countries.filter { $0.status == TravelStatus.wantToVisit.rawValue }.count
        cityCount    = cities.filter { $0.status != TravelStatus.none.rawValue }.count
        attractionCount = attractions.filter { $0.status != TravelStatus.none.rawValue }.count
        totalCountries = countries.count

        let doneCount = visitedCount + livedInCount
        completionPercent = totalCountries > 0 ? Double(doneCount) / Double(totalCountries) : 0

        let continents = Set(countries.compactMap { $0.continent })
        continentsCovered = continents.filter { continent in
            countries.filter { $0.continent == continent &&
                ($0.status == TravelStatus.visited.rawValue || $0.status == TravelStatus.livedIn.rawValue)
            }.count > 0
        }.count

        continentBreakdown = Continent.allCases.map { c in
            let all = countries.filter { $0.continent == c.rawValue }
            let done = all.filter { $0.status == TravelStatus.visited.rawValue || $0.status == TravelStatus.livedIn.rawValue }
            return ContinentStat(continent: c.rawValue, visited: done.count, total: all.count)
        }
    }
}

struct StatsDashboardView: View {
    @State private var viewModel = StatsViewModel()
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero completion ring
                    completionRing
                    // Big number grid
                    bigNumberGrid
                    // Continent bar chart
                    continentChart
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("My Travel Stats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task { viewModel.refresh(context: ctx) }
            .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange)) { _ in
                viewModel.refresh(context: ctx)
            }
        }
    }

    // MARK: - Components

    private var completionRing: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color(.systemFill), lineWidth: 16)
                    .frame(width: 140, height: 140)
                Circle()
                    .trim(from: 0, to: viewModel.completionPercent)
                    .stroke(
                        AngularGradient(colors: [.cyan, .blue, .purple], center: .center),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: viewModel.completionPercent)
                VStack(spacing: 2) {
                    Text("\(Int(viewModel.completionPercent * 100))%")
                        .font(.title.bold().monospacedDigit())
                    Text("World\nComplete")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            }
            Text("\(viewModel.visitedCount + viewModel.livedInCount) of \(viewModel.totalCountries) countries")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var bigNumberGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            BigStatCard(value: viewModel.visitedCount, label: "Countries\nVisited", icon: TravelStatus.visited.icon, color: TravelStatus.visited.color)
            BigStatCard(value: viewModel.livedInCount, label: "Countries\nLived In", icon: TravelStatus.livedIn.icon, color: TravelStatus.livedIn.color)
            BigStatCard(value: viewModel.wantToCount, label: "On\nWishlist", icon: TravelStatus.wantToVisit.icon, color: TravelStatus.wantToVisit.color)
            BigStatCard(value: viewModel.cityCount, label: "Cities\nExplored", icon: "building.2.fill", color: .orange)
            BigStatCard(value: viewModel.attractionCount, label: "Attractions\nSaved", icon: "mappin.circle.fill", color: .pink)
            BigStatCard(value: viewModel.continentsCovered, label: "Continents\nCovered", icon: "globe", color: .teal)
        }
    }

    private var continentChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Continent")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Chart(viewModel.continentBreakdown) { stat in
                BarMark(
                    x: .value("Visited", stat.visited),
                    y: .value("Continent", stat.continent)
                )
                .foregroundStyle(stat.color)
                .annotation(position: .trailing) {
                    Text("\(stat.visited)/\(stat.total)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 220)
            .chartXAxis(.hidden)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }
}

struct BigStatCard: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text("\(value)")
                .font(.title2.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.10))
        )
    }
}

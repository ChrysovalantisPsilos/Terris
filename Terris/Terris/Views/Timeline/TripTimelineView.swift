//
//  TripTimelineView.swift
//  Terris
//

import SwiftUI
import CoreData

struct TripTimelineView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)],
        predicate: nil
    ) private var trips: FetchedResults<Trip>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Country.firstVisitDate, ascending: false)],
        predicate: NSPredicate(format: "status != %d AND firstVisitDate != nil", TravelStatus.none.rawValue)
    ) private var visitedCountries: FetchedResults<Country>

    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddTrip = false
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    private var years: [Int] {
        var ys = Set<Int>()
        for c in visitedCountries {
            if let d = c.firstVisitDate {
                ys.insert(Calendar.current.component(.year, from: d))
            }
        }
        for t in trips {
            if let d = t.startDate {
                ys.insert(Calendar.current.component(.year, from: d))
            }
        }
        if ys.isEmpty { ys.insert(selectedYear) }
        return ys.sorted(by: >)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Year selector
                yearSelector
                // Timeline content
                if trips.isEmpty && visitedCountries.isEmpty {
                    emptyState
                } else {
                    timelineList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddTrip = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddTrip) { AddTripSheet() }
        }
    }

    // MARK: - Sub-views

    private var yearSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(years, id: \.self) { year in
                    Button {
                        withAnimation { selectedYear = year }
                    } label: {
                        Text(String(year))
                            .font(.subheadline.weight(selectedYear == year ? .bold : .regular))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedYear == year ? Color.accentColor : Color(.secondarySystemFill))
                            )
                            .foregroundStyle(selectedYear == year ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var timelineList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                // Trips for selected year
                let yearTrips = trips.filter {
                    guard let d = $0.startDate else { return false }
                    return Calendar.current.component(.year, from: d) == selectedYear
                }
                // Countries for selected year
                let yearCountries = visitedCountries.filter {
                    guard let d = $0.firstVisitDate else { return false }
                    return Calendar.current.component(.year, from: d) == selectedYear
                }

                if !yearTrips.isEmpty {
                    SectionHeader(title: "Trips")
                    ForEach(yearTrips, id: \.id) { trip in
                        TripCard(trip: trip)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                }

                if !yearCountries.isEmpty {
                    SectionHeader(title: "Countries First Visited")
                    ForEach(yearCountries, id: \.id) { country in
                        CountryTimelineRow(country: country)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("No trips yet")
                .font(.title3.bold())
            Text("Start exploring! Mark countries on the globe\nor add your first trip.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Add Trip") { showingAddTrip = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Trip Card

struct TripCard: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.title ?? "Trip")
                        .font(.subheadline.bold())
                    if let start = trip.startDate, let end = trip.endDate {
                        Text("\(start.formatted(date: .abbreviated, time: .omitted)) – \(end.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let type = trip.tripType, let tt = TripType(rawValue: type) {
                    Image(systemName: tt.icon)
                        .foregroundStyle(.tint)
                        .font(.subheadline)
                }
            }
            // Countries
            let countries = trip.countries as? Set<Country> ?? []
            if !countries.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(countries).sorted { ($0.name ?? "") < ($1.name ?? "") }, id: \.id) { c in
                            Text(flagEmoji(for: c.isoCode ?? "") + " " + (c.name ?? ""))
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color(.tertiarySystemFill)))
                        }
                    }
                }
            }
            if let notes = trip.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func flagEmoji(for isoCode: String) -> String {
        guard isoCode.count == 2 else { return "" }
        let base: UInt32 = 127397
        var result = ""
        for scalar in isoCode.uppercased().unicodeScalars {
            guard let s = Unicode.Scalar(base + scalar.value) else { continue }
            result.append(Character(s))
        }
        return result
    }
}

struct CountryTimelineRow: View {
    let country: Country

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

    var body: some View {
        HStack(spacing: 12) {
            // Timeline dot
            VStack {
                Circle()
                    .fill(TravelStatus(rawValue: country.status)?.color ?? .gray)
                    .frame(width: 10, height: 10)
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 1)
            }
            .frame(width: 20)
            HStack {
                Text(flagEmoji(for: country.isoCode ?? ""))
                Text(country.name ?? "")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if let d = country.firstVisitDate {
                    Text(d.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
    }
}

// MARK: - Add Trip Sheet

struct AddTripSheet: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var tripType: TripType = .solo
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    TextField("Title (e.g. Summer in Japan)", text: $title)
                    Picker("Type", selection: $tripType) {
                        ForEach(TripType.allCases) { t in
                            Label(t.rawValue, systemImage: t.icon).tag(t)
                        }
                    }
                }
                Section("Dates") {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trip = Trip(context: ctx)
                        trip.id = UUID()
                        trip.title = title.isEmpty ? "My Trip" : title
                        trip.startDate = startDate
                        trip.endDate = endDate
                        trip.tripType = tripType.rawValue
                        trip.notes = notes.isEmpty ? nil : notes
                        try? ctx.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

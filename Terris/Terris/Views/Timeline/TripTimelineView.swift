//
//  TripTimelineView.swift
//  Terris
//

import SwiftUI
import CoreData

struct TripTimelineView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)]
    ) private var trips: FetchedResults<Trip>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Country.firstVisitDate, ascending: false)],
        predicate: NSPredicate(format: "status != %d AND firstVisitDate != nil", TravelStatus.none.rawValue)
    ) private var visitedCountries: FetchedResults<Country>

    @Environment(\.managedObjectContext) private var ctx
    @State private var showingAddTrip = false
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var expandedTripID: UUID? = nil

    private var years: [Int] {
        var ys = Set<Int>()
        for c in visitedCountries {
            if let d = c.firstVisitDate { ys.insert(Calendar.current.component(.year, from: d)) }
        }
        for t in trips {
            if let d = t.startDate { ys.insert(Calendar.current.component(.year, from: d)) }
        }
        // Always show a range: from earliest data year to current year
        if let minYear = ys.min() {
            let currentYear = Calendar.current.component(.year, from: Date())
            for y in minYear...currentYear { ys.insert(y) }
        }
        if ys.isEmpty { ys.insert(Calendar.current.component(.year, from: Date())) }
        return ys.sorted(by: >)
    }

    var body: some View {
        VStack(spacing: 0) {
            yearSelector
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
                Button { showingAddTrip = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAddTrip) { AddTripSheet() }
    }

    // MARK: - Year selector

    private var yearSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(years, id: \.self) { year in
                    Button {
                        withAnimation(.spring(response: 0.3)) { selectedYear = year }
                    } label: {
                        Text(String(year))
                            .font(.subheadline.weight(selectedYear == year ? .bold : .regular))
                            .padding(.horizontal, 16).padding(.vertical, 7)
                            .background(Capsule().fill(selectedYear == year ? Color.accentColor : Color(.secondarySystemFill)))
                            .foregroundStyle(selectedYear == year ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Timeline list

    private var timelineList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                let yearTrips = trips.filter {
                    guard let d = $0.startDate else { return false }
                    return Calendar.current.component(.year, from: d) == selectedYear
                }
                let yearCountries = visitedCountries.filter {
                    guard let d = $0.firstVisitDate else { return false }
                    return Calendar.current.component(.year, from: d) == selectedYear
                }

                if yearTrips.isEmpty && yearCountries.isEmpty {
                    noDataForYear
                } else {
                    if !yearTrips.isEmpty {
                        SectionHeader(title: "Trips (\(yearTrips.count))")
                        ForEach(yearTrips, id: \.id) { trip in
                            TripCard(
                                trip: trip,
                                isExpanded: expandedTripID == trip.id,
                                onTap: {
                                    withAnimation(.spring(response: 0.35)) {
                                        expandedTripID = expandedTripID == trip.id ? nil : trip.id
                                    }
                                },
                                onDelete: { deleteTrip(trip) }
                            )
                            .padding(.horizontal, 16).padding(.bottom, 12)
                        }
                    }
                    if !yearCountries.isEmpty {
                        SectionHeader(title: "Countries First Visited")
                        ForEach(yearCountries, id: \.id) { country in
                            CountryTimelineRow(country: country)
                                .padding(.horizontal, 16).padding(.bottom, 8)
                        }
                    }
                }
            }
            .padding(.top, 12).padding(.bottom, 40)
        }
    }

    private var noDataForYear: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 44)).foregroundStyle(.tertiary)
            Text("No travel in \(selectedYear)")
                .font(.headline)
            Text("Add a trip or mark countries visited this year.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button("Add Trip") { showingAddTrip = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 56)).foregroundStyle(.tertiary)
            Text("No trips yet").font(.title3.bold())
            Text("Mark countries on the globe or add your first trip.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button("Add Trip") { showingAddTrip = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, 60)
    }

    private func deleteTrip(_ trip: Trip) {
        ctx.delete(trip)
        try? ctx.save()
    }
}

// MARK: - Trip Card

struct TripCard: View {
    let trip: Trip
    let isExpanded: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    private var countries: [Country] {
        (trip.countries as? Set<Country> ?? []).sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed header — always visible
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Trip type icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(tripTypeColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: tripTypeIcon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(tripTypeColor)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(trip.title ?? "Trip")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        if let start = trip.startDate, let end = trip.endDate {
                            Text(dateRangeString(start: start, end: end))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        // Country flags preview
                        if !countries.isEmpty {
                            Text(countries.prefix(5).map { flagEmoji(for: $0.isoCode ?? "") }.joined(separator: " "))
                                .font(.caption)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            // Expanded detail
            if isExpanded {
                Divider().padding(.horizontal, 14)

                VStack(alignment: .leading, spacing: 14) {
                    // Duration badge
                    if let start = trip.startDate, let end = trip.endDate {
                        let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
                        HStack(spacing: 6) {
                            Label("\(days + 1) days", systemImage: "clock")
                            if let type = trip.tripType, let tt = TripType(rawValue: type) {
                                Text("·").foregroundStyle(.secondary)
                                Label(tt.rawValue, systemImage: tt.icon)
                            }
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    }

                    // Countries visited
                    if !countries.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Countries").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            FlowLayout(spacing: 6) {
                                ForEach(countries, id: \.id) { c in
                                    HStack(spacing: 4) {
                                        Text(flagEmoji(for: c.isoCode ?? ""))
                                        Text(c.name ?? "").font(.caption.weight(.medium))
                                    }
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Capsule().fill(Color(.tertiarySystemFill)))
                                }
                            }
                        }
                    }

                    // Notes
                    if let notes = trip.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(notes).font(.subheadline).foregroundStyle(.primary)
                        }
                    }

                    // Delete button
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete Trip", systemImage: "trash")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground)))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
    }

    private var tripTypeIcon: String {
        if let type = trip.tripType, let tt = TripType(rawValue: type) { return tt.icon }
        return "airplane"
    }
    private var tripTypeColor: Color {
        if let type = trip.tripType, let tt = TripType(rawValue: type) {
            switch tt {
            case .solo: return .blue
            case .couple: return .pink
            case .family: return .orange
            case .business: return .indigo
            case .backpacking: return .green
            case .group: return .purple
            case .luxury: return .yellow
            }
        }
        return .blue
    }

    private func dateRangeString(start: Date, end: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let yearFmt = DateFormatter()
        yearFmt.dateFormat = "yyyy"
        return "\(fmt.string(from: start)) – \(fmt.string(from: end)), \(yearFmt.string(from: start))"
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

// MARK: - Simple flow layout for country tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { $0.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }.reduce(0) { $0 + $1 + spacing }
        return CGSize(width: proposal.width ?? 0, height: max(0, height - spacing))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowH = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for view in row {
                let s = view.sizeThatFits(.unspecified)
                view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
            y += rowH + spacing
        }
    }
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var x: CGFloat = 0
        let maxW = proposal.width ?? .infinity
        for view in subviews {
            let w = view.sizeThatFits(.unspecified).width
            if x + w > maxW, !rows[rows.count - 1].isEmpty {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(view)
            x += w + spacing
        }
        return rows
    }
}

// MARK: - Country timeline row

struct CountryTimelineRow: View {
    let country: Country
    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(TravelStatus(rawValue: country.status)?.color ?? .gray)
                .frame(width: 10, height: 10)
            Text(flagEmoji(for: country.isoCode ?? ""))
            Text(country.name ?? "").font(.subheadline.weight(.medium))
            Spacer()
            if let d = country.firstVisitDate {
                Text(d.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
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

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            .padding(.horizontal, 16).padding(.bottom, 6)
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
                    TextEditor(text: $notes).frame(minHeight: 80)
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

//
//  CountryDetailPage.swift
//  Terris
//
//  Full-page country detail: hero header, status picker, dates,
//  notes, regions → cities → attractions hierarchy, photos.
//

import SwiftUI
import CoreData
import MapKit
import CoreLocation

struct CountryDetailPage: View {
    @ObservedObject var country: Country
    @Environment(\.managedObjectContext) private var ctx
    @State private var currentStatus: TravelStatus
    @State private var showAddRegion = false

    init(country: Country) {
        self.country = country
        _currentStatus = State(initialValue: TravelStatus(rawValue: country.status) ?? .none)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroHeader
                VStack(spacing: 16) {
                    statusCard
                    if currentStatus != .none { datesCard }
                    notesCard
                    hierarchyCard
                    photosCard
                }
                .padding(16)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(country.name ?? "Country")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddRegion) {
            AddPlaceSheet(title: "Add Region", locationHint: country.name ?? "") { name in
                let r = Region(context: ctx); r.id = UUID()
                r.name = name; r.status = TravelStatus.none.rawValue; r.country = country
                try? ctx.save()
            }
        }
    }

    // MARK: - Hero header

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Background gradient using status colour
            LinearGradient(
                colors: [currentStatus.color.opacity(0.6), currentStatus.color.opacity(0.2)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(height: 160)

            HStack(alignment: .bottom, spacing: 14) {
                Text(flagEmoji(for: country.isoCode ?? ""))
                    .font(.system(size: 64))
                    .shadow(radius: 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(country.name ?? "").font(.title2.bold()).foregroundStyle(.white)
                    if let continent = country.continent {
                        Label(continent, systemImage: "globe")
                            .font(.caption).foregroundStyle(.white.opacity(0.8))
                    }
                    // Star rating
                    HStack(spacing: 3) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: Float(i) <= country.rating ? "star.fill" : "star")
                                .font(.caption).foregroundStyle(Float(i) <= country.rating ? .yellow : .white.opacity(0.5))
                                .onTapGesture { country.rating = Float(i); try? ctx.save() }
                        }
                    }
                }
                Spacer()
            }
            .padding(16)
        }
    }

    // MARK: - Status card

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Travel Status", systemImage: "tag.fill")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(TravelStatus.allCases, id: \.id) { status in
                    StatusChip(status: status, isSelected: currentStatus == status) {
                        currentStatus = status
                        country.status = status.rawValue
                        try? ctx.save()
                        NotificationCenter.default.post(name: .countryStatusChanged,
                            object: nil, userInfo: ["isoCode": country.isoCode ?? ""])
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    // MARK: - Dates card

    private var datesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(currentStatus == .livedIn ? "Residence Period" : "Visit Dates", systemImage: "calendar")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            DateRow(label: currentStatus == .livedIn ? "Moved In" : "First Visit",
                    date: Binding(get: { country.firstVisitDate },
                                  set: { country.firstVisitDate = $0; try? ctx.save() }))
            Divider()
            DateRow(label: currentStatus == .livedIn ? "Moved Out" : "Last Visit",
                    date: Binding(get: { country.lastVisitDate },
                                  set: { country.lastVisitDate = $0; try? ctx.save() }))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    // MARK: - Notes card

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Notes & Memories", systemImage: "note.text")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            TextEditor(text: Binding(
                get: { country.notes ?? "" },
                set: { country.notes = $0.isEmpty ? nil : $0; try? ctx.save() }
            ))
            .font(.subheadline)
            .frame(minHeight: 80, maxHeight: 160)
            .scrollContentBackground(.hidden)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    // MARK: - Hierarchy card

    private var hierarchyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Regions & Cities", systemImage: "map.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button { showAddRegion = true } label: {
                    Image(systemName: "plus.circle.fill").foregroundStyle(.tint)
                }
            }
            let regions = (country.regions as? Set<Region> ?? [])
                .sorted { ($0.name ?? "") < ($1.name ?? "") }
            if regions.isEmpty {
                emptyHierarchy
            } else {
                ForEach(regions, id: \.id) { region in
                    RegionExpandableRow(region: region)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var emptyHierarchy: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "map").font(.system(size: 28)).foregroundStyle(.tertiary)
                Text("No regions yet").font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 10)
    }

    // MARK: - Photos card

    @ViewBuilder
    private var photosCard: some View {
        let photos = (country.photos as? Set<TravelPhoto> ?? [])
            .sorted { ($0.takenDate ?? .distantPast) > ($1.takenDate ?? .distantPast) }
        Group {
            if !photos.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Photos (\(photos.count))", systemImage: "photo.stack")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        Spacer()
                        Text("Hold to delete")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(photos, id: \.id) { photo in
                                PhotoThumbnail(photo: photo)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            deletePhoto(photo)
                                        } label: {
                                            Label("Delete Photo", systemImage: "trash")
                                        }
                                    }
                                    .overlay(alignment: .topTrailing) {
                                        // Quick delete X badge
                                        Button {
                                            deletePhoto(photo)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundStyle(.white)
                                                .background(Color.black.opacity(0.5), in: Circle())
                                        }
                                        .offset(x: 4, y: -4)
                                    }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
            }
        }
    }

    private func deletePhoto(_ photo: TravelPhoto) {
        ctx.delete(photo)
        try? ctx.save()
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

// MARK: - Status chip

struct StatusChip: View {
    let status: TravelStatus
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isSelected ? status.color : Color(.secondarySystemFill))
                        .frame(width: 40, height: 40)
                    Image(systemName: status.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .secondary)
                }
                Text(status == .none ? "None" : status.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isSelected ? status.color : .secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 56)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(.spring(response: 0.25), value: isSelected)
    }
}

// MARK: - Region expandable row

struct RegionExpandableRow: View {
    @ObservedObject var region: Region
    @Environment(\.managedObjectContext) private var ctx
    @State private var expanded = false
    @State private var showAddCity = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) { expanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "map.fill")
                        .foregroundStyle(TravelStatus(rawValue: region.status)?.color ?? .secondary)
                        .font(.subheadline)
                    Text(region.name ?? "Region").font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                    Spacer()
                    let cityCount = (region.cities as? Set<City> ?? []).count
                    if cityCount > 0 {
                        Text("\(cityCount) cities").font(.caption2).foregroundStyle(.secondary)
                    }
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if expanded {
                let cities = (region.cities as? Set<City> ?? []).sorted { ($0.name ?? "") < ($1.name ?? "") }
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(cities, id: \.id) { city in
                        CityExpandableRow(city: city).padding(.leading, 20)
                    }
                    Button { showAddCity = true } label: {
                        Label("Add City", systemImage: "plus")
                            .font(.caption.weight(.medium)).foregroundStyle(.tint)
                            .padding(.leading, 20).padding(.vertical, 6)
                    }
                }
                .sheet(isPresented: $showAddCity) {
                    AddPlaceSheet(
                        title: "Add City",
                        locationHint: [region.name, region.country?.name].compactMap { $0 }.joined(separator: ", ")
                    ) { name in
                        let c = City(context: ctx); c.id = UUID()
                        c.name = name; c.status = TravelStatus.none.rawValue; c.region = region
                        try? ctx.save()
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - City expandable row with Attractions

struct CityExpandableRow: View {
    @ObservedObject var city: City
    @Environment(\.managedObjectContext) private var ctx
    @State private var expanded = false
    @State private var showAddAttraction = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) { expanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    // Status dot
                    Circle()
                        .fill(TravelStatus(rawValue: city.status)?.color ?? Color(.systemGray4))
                        .frame(width: 8, height: 8)
                    Text(city.name ?? "City").font(.subheadline).foregroundStyle(.primary)
                    Spacer()
                    let attrCount = (city.attractions as? Set<Attraction> ?? []).count
                    if attrCount > 0 {
                        Text("\(attrCount) spots").font(.caption2).foregroundStyle(.secondary)
                    }
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.vertical, 7)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 4) {
                    // City status picker
                    let cityStatus = TravelStatus(rawValue: city.status) ?? .none
                    HStack(spacing: 8) {
                        ForEach([TravelStatus.none, .wantToVisit, .visited, .livedIn], id: \.id) { s in
                            Button {
                                city.status = s.rawValue; try? ctx.save()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: s.icon).font(.caption2)
                                    Text(s == .none ? "None" : s.label).font(.caption2)
                                }
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Capsule().fill(cityStatus == s ? s.color.opacity(0.2) : Color(.systemFill)))
                                .foregroundStyle(cityStatus == s ? s.color : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 4)

                    // Attractions
                    let attractions = (city.attractions as? Set<Attraction> ?? [])
                        .sorted { ($0.name ?? "") < ($1.name ?? "") }
                    ForEach(attractions, id: \.id) { attr in
                        AttractionRow(attraction: attr)
                            .padding(.leading, 16)
                    }

                    Button { showAddAttraction = true } label: {
                        Label("Add Attraction", systemImage: "plus")
                            .font(.caption.weight(.medium)).foregroundStyle(.tint)
                            .padding(.leading, 16).padding(.vertical, 4)
                    }
                }
                .sheet(isPresented: $showAddAttraction) {
                    AddPlaceSheet(
                        title: "Add Attraction",
                        locationHint: [city.name, city.region?.country?.name].compactMap { $0 }.joined(separator: ", ")
                    ) { name in
                        let a = Attraction(context: ctx); a.id = UUID()
                        a.name = name; a.status = TravelStatus.visited.rawValue; a.city = city
                        try? ctx.save()
                    }
                }
            }
        }
    }
}

// MARK: - Attraction row

struct AttractionRow: View {
    @ObservedObject var attraction: Attraction
    @Environment(\.managedObjectContext) private var ctx

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.circle.fill")
                .font(.caption)
                .foregroundStyle(TravelStatus(rawValue: attraction.status)?.color ?? .secondary)
            Text(attraction.name ?? "Attraction")
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
            // Quick visited toggle
            Button {
                let current = TravelStatus(rawValue: attraction.status) ?? .none
                attraction.status = (current == .visited ? TravelStatus.none : .visited).rawValue
                try? ctx.save()
            } label: {
                Image(systemName: TravelStatus(rawValue: attraction.status) == .visited ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(TravelStatus(rawValue: attraction.status) == .visited ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 5)
    }
}

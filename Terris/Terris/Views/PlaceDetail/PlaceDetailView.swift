//
//  PlaceDetailView.swift
//  Terris
//

import SwiftUI
import CoreData

struct PlaceDetailView: View {
    @ObservedObject var country: Country
    @Environment(\.managedObjectContext) private var ctx
    @State private var currentStatus: TravelStatus
    @State private var showingAddCity = false
    @State private var showingAddRegion = false
    @State private var drillLevel: DrillLevel = .country
    @State private var selectedRegion: Region?

    enum DrillLevel { case country, region }

    init(country: Country) {
        self.country = country
        _currentStatus = State(initialValue: TravelStatus(rawValue: country.status) ?? .none)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection
                // Status picker
                statusSection
                // Metadata
                if currentStatus != .none {
                    metadataSection
                }
                // Hierarchy
                hierarchySection
                // Photo strip
                if let photos = country.photos as? Set<TravelPhoto>, !photos.isEmpty {
                    photoStripSection(photos: photos.sorted { ($0.takenDate ?? .distantPast) > ($1.takenDate ?? .distantPast) })
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(spacing: 12) {
            // Flag emoji derived from ISO code
            Text(flagEmoji(for: country.isoCode ?? ""))
                .font(.system(size: 44))
            VStack(alignment: .leading, spacing: 2) {
                Text(country.name ?? "Unknown")
                    .font(.title2.bold())
                if let continent = country.continent {
                    Label(continent, systemImage: "globe")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            // Rating stars
            ratingView
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Status")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            StatusPickerView(status: $currentStatus)
                .onChange(of: currentStatus) { _, new in
                    country.status = new.rawValue
                    try? ctx.save()
                    // Notify globe to refresh overlay colour immediately
                    NotificationCenter.default.post(
                        name: .countryStatusChanged,
                        object: nil,
                        userInfo: ["isoCode": country.isoCode ?? ""]
                    )
                }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if currentStatus == .livedIn {
                DateRow(label: "Moved In", date: Binding(
                    get: { country.firstVisitDate },
                    set: { country.firstVisitDate = $0; try? ctx.save() }
                ))
                DateRow(label: "Moved Out", date: Binding(
                    get: { country.lastVisitDate },
                    set: { country.lastVisitDate = $0; try? ctx.save() }
                ))
            } else {
                DateRow(label: "First Visit", date: Binding(
                    get: { country.firstVisitDate },
                    set: { country.firstVisitDate = $0; try? ctx.save() }
                ))
                DateRow(label: "Last Visit", date: Binding(
                    get: { country.lastVisitDate },
                    set: { country.lastVisitDate = $0; try? ctx.save() }
                ))
            }
            NotesRow(notes: Binding(
                get: { country.notes ?? "" },
                set: { country.notes = $0.isEmpty ? nil : $0; try? ctx.save() }
            ))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var hierarchySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Regions & Cities")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showingAddRegion = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            let regions = (country.regions as? Set<Region> ?? []).sorted { ($0.name ?? "") < ($1.name ?? "") }
            if regions.isEmpty {
                emptyHierarchyView
            } else {
                ForEach(regions, id: \.id) { region in
                    RegionRowView(region: region)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
        .sheet(isPresented: $showingAddRegion) {
            AddPlaceSheet(title: "Add Region", locationHint: country.name ?? "") { name in
                let r = Region(context: ctx)
                r.id = UUID()
                r.name = name
                r.status = TravelStatus.none.rawValue
                r.country = country
                try? ctx.save()
            }
        }
    }

    private var emptyHierarchyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "map")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No regions added yet")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func photoStripSection(photos: [TravelPhoto]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Photos (\(photos.count))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(photos, id: \.id) { photo in
                        PhotoThumbnail(photo: photo)
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var ratingView: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: Double(i) <= Double(country.rating) ? "star.fill" : "star")
                    .font(.caption)
                    .foregroundStyle(Double(i) <= Double(country.rating) ? Color.yellow : Color(.tertiaryLabel))
                    .onTapGesture {
                        country.rating = Float(i)
                        try? ctx.save()
                    }
            }
        }
    }

    // MARK: - Helpers

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

// MARK: - Sub-components

struct DateRow: View {
    let label: String
    @Binding var date: Date?
    @State private var isExpanded = false

    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            if let d = date {
                Text(d.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
            } else {
                Text("Not set").font(.subheadline).foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isExpanded.toggle() }
        if isExpanded {
            DatePicker("", selection: Binding(
                get: { date ?? Date() },
                set: { date = $0 }
            ), displayedComponents: .date)
            .datePickerStyle(.compact)
        }
    }
}

struct NotesRow: View {
    @Binding var notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes").font(.subheadline).foregroundStyle(.secondary)
            TextEditor(text: $notes)
                .font(.subheadline)
                .frame(minHeight: 64, maxHeight: 120)
                .scrollContentBackground(.hidden)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

struct RegionRowView: View {
    @ObservedObject var region: Region
    @Environment(\.managedObjectContext) private var ctx
    @State private var isExpanded = false
    @State private var showAddCity = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "map.fill")
                    .foregroundStyle(TravelStatus(rawValue: region.status)?.color ?? .secondary)
                    .font(.subheadline)
                Text(region.name ?? "Region")
                    .font(.subheadline.weight(.medium))
                Spacer()
                let cities = (region.cities as? Set<City> ?? [])
                if !cities.isEmpty {
                    Text("\(cities.count) cities")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation { isExpanded.toggle() } }

            if isExpanded {
                let sortedCities = (region.cities as? Set<City> ?? []).sorted { ($0.name ?? "") < ($1.name ?? "") }
                ForEach(sortedCities, id: \.id) { city in
                    CityRowView(city: city)
                        .padding(.leading, 20)
                }
                Button {
                    showAddCity = true
                } label: {
                    Label("Add City", systemImage: "plus")
                        .font(.caption)
                        .foregroundStyle(.tint)
                        .padding(.leading, 20)
                        .padding(.top, 4)
                }
                .sheet(isPresented: $showAddCity) {
                    AddPlaceSheet(
                        title: "Add City",
                        locationHint: [region.name, region.country?.name].compactMap { $0 }.joined(separator: ", ")
                    ) { name in
                        let c = City(context: ctx)
                        c.id = UUID()
                        c.name = name
                        c.status = TravelStatus.none.rawValue
                        c.region = region
                        try? ctx.save()
                    }
                }
            }
        }
    }
}

struct CityRowView: View {
    @ObservedObject var city: City
    @Environment(\.managedObjectContext) private var ctx
    @State private var isExpanded = false
    @State private var showAddAttraction = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundStyle(TravelStatus(rawValue: city.status)?.color ?? .secondary)
                    .font(.caption)
                Text(city.name ?? "City")
                    .font(.caption.weight(.medium))
                Spacer()
                let attrs = (city.attractions as? Set<Attraction> ?? [])
                if !attrs.isEmpty {
                    Text("\(attrs.count) spots")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation { isExpanded.toggle() } }

            if isExpanded {
                let sortedAttrs = (city.attractions as? Set<Attraction> ?? []).sorted { ($0.name ?? "") < ($1.name ?? "") }
                ForEach(sortedAttrs, id: \.id) { attr in
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(TravelStatus(rawValue: attr.status)?.color ?? .secondary)
                        Text(attr.name ?? "Place")
                            .font(.caption2)
                    }
                    .padding(.leading, 20)
                    .padding(.vertical, 2)
                }
                Button {
                    showAddAttraction = true
                } label: {
                    Label("Add Attraction", systemImage: "plus")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                        .padding(.leading, 20)
                }
                .sheet(isPresented: $showAddAttraction) {
                    AddPlaceSheet(
                        title: "Add Attraction",
                        locationHint: [city.name, city.region?.country?.name].compactMap { $0 }.joined(separator: ", ")
                    ) { name in
                        let a = Attraction(context: ctx)
                        a.id = UUID()
                        a.name = name
                        a.status = TravelStatus.visited.rawValue
                        a.city = city
                        try? ctx.save()
                    }
                }
            }
        }
    }
}

struct PhotoThumbnail: View {
    let photo: TravelPhoto

    var body: some View {
        Group {
            if let data = photo.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(.tertiarySystemFill)
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct AddPlaceSheet: View {
    let title: String
    /// Optional hint to scope autocomplete (e.g. country name or city name)
    var locationHint: String = ""
    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var suggestions: [String] = []
    @FocusState private var focused: Bool
    private let completer = PlaceCompleter()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search \(title.lowercased())…", text: $query)
                        .focused($focused)
                        .autocorrectionDisabled()
                        .onChange(of: query) { _, newValue in
                            completer.search(newValue, hint: locationHint) { results in
                                suggestions = results
                            }
                        }
                    if !query.isEmpty {
                        Button { query = ""; suggestions = [] } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Suggestions list
                List {
                    // Allow typing a custom name directly
                    if !query.isEmpty {
                        Button {
                            commit(query)
                        } label: {
                            Label("Add \"\(query)\"", systemImage: "plus.circle")
                                .font(.subheadline)
                        }
                    }
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            commit(suggestion)
                        } label: {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(.tint)
                                Text(suggestion)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func commit(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onAdd(trimmed)
        dismiss()
    }
}

// MARK: - MKLocalSearchCompleter wrapper

final class PlaceCompleter: NSObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    private var onResults: (([String]) -> Void)?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func search(_ query: String, hint: String, completion: @escaping ([String]) -> Void) {
        onResults = completion
        if !hint.isEmpty {
            completer.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
            )
        }
        completer.queryFragment = query.isEmpty ? "" : (hint.isEmpty ? query : "\(query), \(hint)")
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let names = completer.results
            .map { r -> String in
                // Return just the title (city/region name) without the subtitle
                r.title
            }
            .filter { !$0.isEmpty }
            // Remove duplicates while preserving order
            .reduce(into: [String]()) { acc, s in
                if !acc.contains(s) { acc.append(s) }
            }
        DispatchQueue.main.async { self.onResults?(Array(names.prefix(8))) }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async { self.onResults?([]) }
    }
}

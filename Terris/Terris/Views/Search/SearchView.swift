//
//  SearchView.swift
//  Terris
//

import SwiftUI
import CoreData

struct SearchView: View {
    var globeVM: GlobeViewModel
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var focused: Bool

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Country.name, ascending: true)])
    private var allCountries: FetchedResults<Country>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \City.name, ascending: true)])
    private var allCities: FetchedResults<City>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Attraction.name, ascending: true)])
    private var allAttractions: FetchedResults<Attraction>

    private var filteredCountries: [Country] {
        guard !query.isEmpty else { return [] }
        return allCountries.filter { ($0.name ?? "").localizedCaseInsensitiveContains(query) }
    }
    private var filteredCities: [City] {
        guard !query.isEmpty else { return [] }
        return allCities.filter { ($0.name ?? "").localizedCaseInsensitiveContains(query) }
    }
    private var filteredAttractions: [Attraction] {
        guard !query.isEmpty else { return [] }
        return allAttractions.filter { ($0.name ?? "").localizedCaseInsensitiveContains(query) }
    }

    private var hasResults: Bool {
        !filteredCountries.isEmpty || !filteredCities.isEmpty || !filteredAttractions.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search countries, cities, attractions…", text: $query)
                        .focused($focused)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                if query.isEmpty {
                    suggestionsView
                } else if !hasResults {
                    noResultsView
                } else {
                    resultsList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        globeVM.searchedISOCode = nil
                        dismiss()
                    }
                }
            }
            .onAppear { focused = true }
            .onChange(of: query) { _, newValue in
                if newValue.isEmpty {
                    globeVM.searchedISOCode = nil
                }
            }
        }
    }

    // MARK: - Sub-views

    private var suggestionsView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("Search Anywhere")
                .font(.title3.bold())
            Text("Find countries, cities, and attractions\nfrom your travel history.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("No Results for \"\(query)\"")
                .font(.headline)
            Text("Try a different spelling or check your travel history.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var resultsList: some View {
        List {
                if !filteredCountries.isEmpty {
                Section("Countries (\(filteredCountries.count))") {
                    ForEach(filteredCountries, id: \.id) { country in
                        CountrySearchRow(country: country)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                globeVM.searchedISOCode = country.isoCode
                                globeVM.selectCountry(country)
                                dismiss()
                            }
                    }
                }
            }
            if !filteredCities.isEmpty {
                Section("Cities (\(filteredCities.count))") {
                    ForEach(filteredCities, id: \.id) { city in
                        CitySearchRow(city: city)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let country = city.region?.country {
                                    globeVM.searchedISOCode = country.isoCode
                                    globeVM.selectCountry(country)
                                }
                                dismiss()
                            }
                    }
                }
            }
            if !filteredAttractions.isEmpty {
                Section("Attractions (\(filteredAttractions.count))") {
                    ForEach(filteredAttractions, id: \.id) { attr in
                        AttractionSearchRow(attraction: attr)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let country = attr.city?.region?.country {
                                    globeVM.searchedISOCode = country.isoCode
                                    globeVM.selectCountry(country)
                                }
                                dismiss()
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Row Views

struct CountrySearchRow: View {
    let country: Country
    var body: some View {
        HStack(spacing: 12) {
            Text(flagEmoji(for: country.isoCode ?? ""))
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(country.name ?? "").font(.subheadline.weight(.medium))
                if let continent = country.continent {
                    Text(continent).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            let s = TravelStatus(rawValue: country.status) ?? .none
            if s != .none {
                Text(s.label)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(s.color.opacity(0.15)))
                    .foregroundStyle(s.color)
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

struct CitySearchRow: View {
    let city: City
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "building.2.fill")
                .foregroundStyle(TravelStatus(rawValue: city.status)?.color ?? .secondary)
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 2) {
                Text(city.name ?? "").font(.subheadline.weight(.medium))
                if let country = city.region?.country {
                    Text(country.name ?? "").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

struct AttractionSearchRow: View {
    let attraction: Attraction
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(TravelStatus(rawValue: attraction.status)?.color ?? .secondary)
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 2) {
                Text(attraction.name ?? "").font(.subheadline.weight(.medium))
                if let city = attraction.city {
                    Text(city.name ?? "").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

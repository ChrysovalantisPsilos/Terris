//
//  SearchScreen.swift
//  Terris
//
//  The search tab: every country, filtered as you type; tap one to open it.
//

import SwiftUI

struct SearchScreen: View {
    @Environment(FootprintStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var query = ""
    @State private var statuses: [String: TravelStatus] = [:]

    var body: some View {
        NavigationStack {
            List(results, id: \.isoCode) { entry in
                Button { router.open(entry.isoCode) } label: {
                    HStack(spacing: 12) {
                        Text(Flag.emoji(for: entry.isoCode)).font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name).foregroundStyle(Theme.ink)
                            Text(entry.continent).font(.caption).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        if let status = statuses[entry.isoCode], status != .none {
                            StatusBadge(status: status)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle("Search")
            .searchable(text: $query, prompt: Text("Countries"))
            .overlay {
                if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
        .task(id: store.version) {
            statuses = Dictionary(store.countryRecords().map { ($0.iso, $0.status) },
                                  uniquingKeysWith: { a, _ in a })
        }
    }

    private var results: [CountryEntry] {
        CountrySearch.filter(store.catalog, query: query)
    }
}

enum CountrySearch {
    /// Name matches, ignoring case and accents; names starting with the query first.
    static func filter(_ entries: [CountryEntry], query: String) -> [CountryEntry] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let sorted = entries.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        guard !q.isEmpty else { return sorted }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        let matches = sorted.filter {
            $0.name.range(of: q, options: options) != nil || $0.isoCode.caseInsensitiveCompare(q) == .orderedSame
        }
        let prefix = matches.filter { $0.name.range(of: q, options: options.union(.anchored)) != nil }
        return prefix + matches.filter { m in !prefix.contains { $0.isoCode == m.isoCode } }
    }
}

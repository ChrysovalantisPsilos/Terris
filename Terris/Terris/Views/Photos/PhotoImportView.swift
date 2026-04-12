//
//  PhotoImportView.swift
//  Terris
//

import SwiftUI
import PhotosUI
import CoreData
import Observation

struct PhotoSuggestion: Identifiable {
    let id = UUID()
    let image: UIImage
    let exifResult: EXIFResult
    var geoMatch: GeoMatchingService.GeoMatch?
    var matchedCountry: Country?
    var confirmed: Bool = false
    var skipped: Bool = false
}

@Observable
final class PhotoImportViewModel {
    var suggestions: [PhotoSuggestion] = []
    var isLoading = false
    var processingMessage = ""

    private let ctx: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.ctx = context
    }

    func process(items: [PhotosPickerItem]) async {
        isLoading = true
        suggestions = []
        for (i, item) in items.enumerated() {
            processingMessage = "Processing photo \(i + 1) of \(items.count)…"
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { continue }
            let exif = EXIFReader.read(from: data)
            var suggestion = PhotoSuggestion(image: image, exifResult: exif)

            if let lat = exif.latitude, let lon = exif.longitude {
                let match = await GeoMatchingService.shared.match(latitude: lat, longitude: lon)
                suggestion.geoMatch = match
                if let iso = match.countryCode {
                    suggestion.matchedCountry = GeoMatchingService.shared.findOrCreateCountry(
                        isoCode: iso, name: match.countryName, in: ctx
                    )
                }
            }
            suggestions.append(suggestion)
        }
        processingMessage = ""
        isLoading = false
    }

    func confirm(suggestionID: UUID) {
        guard let idx = suggestions.firstIndex(where: { $0.id == suggestionID }) else { return }
        let s = suggestions[idx]
        guard let imageData = s.image.jpegData(compressionQuality: 0.8) else { return }

        let photo = TravelPhoto(context: ctx)
        photo.id = UUID()
        photo.imageData = imageData
        photo.takenDate = s.exifResult.takenDate
        photo.latitude = s.exifResult.latitude ?? 0
        photo.longitude = s.exifResult.longitude ?? 0
        photo.suggestedPlaceName = s.geoMatch?.cityName ?? s.geoMatch?.countryName
        photo.country = s.matchedCountry

        // Auto-mark country as visited if not already set
        if let country = s.matchedCountry,
           country.status == TravelStatus.none.rawValue {
            country.status = TravelStatus.visited.rawValue
            country.firstVisitDate = s.exifResult.takenDate ?? Date()
        }

        try? ctx.save()
        suggestions[idx].confirmed = true
    }

    func skip(suggestionID: UUID) {
        guard let idx = suggestions.firstIndex(where: { $0.id == suggestionID }) else { return }
        suggestions[idx].skipped = true
    }
}

struct PhotoImportView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PhotoImportViewModel
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingPicker = false

    init() {
        _viewModel = State(initialValue: PhotoImportViewModel(context: PersistenceController.shared.container.viewContext))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.suggestions.isEmpty {
                    emptyPickerView
                } else {
                    suggestionList
                }
            }
            .navigationTitle("Import Photos")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(selection: $selectedItems, maxSelectionCount: 50, matching: .images) {
                        Label("Select Photos", systemImage: "photo.badge.plus")
                    }
                    .onChange(of: selectedItems) { _, items in
                        Task { await viewModel.process(items: items) }
                    }
                }
            }
        }
    }

    // MARK: - Sub-views

    private var emptyPickerView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            Text("Import Travel Photos")
                .font(.title3.bold())
            Text("Select photos from your library. Terris reads GPS metadata to automatically suggest matching countries and cities.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            PhotosPicker(selection: $selectedItems, maxSelectionCount: 50, matching: .images) {
                Label("Select Photos", systemImage: "photo.badge.plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .onChange(of: selectedItems) { _, items in
                Task { await viewModel.process(items: items) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text(viewModel.processingMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var suggestionList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                let pending = viewModel.suggestions.filter { !$0.confirmed && !$0.skipped }
                let done = viewModel.suggestions.filter { $0.confirmed || $0.skipped }

                if !pending.isEmpty {
                    SectionHeader(title: "Review Matches (\(pending.count))")
                    ForEach(pending) { s in
                        PhotoSuggestionCard(suggestion: s,
                            onConfirm: { viewModel.confirm(suggestionID: s.id) },
                            onSkip: { viewModel.skip(suggestionID: s.id) }
                        )
                        .padding(.horizontal, 16)
                    }
                }
                if !done.isEmpty {
                    SectionHeader(title: "Processed (\(done.count))")
                    ForEach(done) { s in
                        ProcessedPhotoRow(suggestion: s)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Suggestion Card

struct PhotoSuggestionCard: View {
    let suggestion: PhotoSuggestion
    let onConfirm: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail
            Image(uiImage: suggestion.image)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                // Match info
                if let match = suggestion.geoMatch, let country = suggestion.matchedCountry {
                    HStack(spacing: 6) {
                        Text(flagEmoji(for: country.isoCode ?? ""))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(country.name ?? match.countryName ?? "Unknown")
                                .font(.subheadline.bold())
                            if let city = match.cityName {
                                Text(city)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    // Confidence badge
                    if suggestion.exifResult.latitude != nil {
                        Label("GPS matched", systemImage: "location.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                } else {
                    Text("No GPS data")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Cannot auto-match")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                // Date
                if let date = suggestion.exifResult.takenDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Action buttons
                HStack(spacing: 8) {
                    Button("Add", action: onConfirm)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.green.opacity(0.15)))
                        .foregroundStyle(.green)
                    Button("Skip", action: onSkip)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color(.secondarySystemFill)))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
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

struct ProcessedPhotoRow: View {
    let suggestion: PhotoSuggestion

    var body: some View {
        HStack(spacing: 12) {
            Image(uiImage: suggestion.image)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(suggestion.matchedCountry?.name ?? "Unlinked")
                .font(.subheadline)
            Spacer()
            if suggestion.confirmed {
                Label("Added", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
            } else {
                Label("Skipped", systemImage: "xmark.circle.fill").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

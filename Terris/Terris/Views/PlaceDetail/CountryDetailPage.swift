// CountryDetailPage.swift — Redesigned immersive country detail page
import SwiftUI
import CoreData
import MapKit
import PhotosUI

// MARK: - Country descriptions

private let countryDescriptions: [String: String] = [
    "GR": "Greece is the cradle of Western civilisation, home to ancient temples, sun-drenched islands, and a culinary tradition stretching back millennia. From the Acropolis to the azure waters of Santorini, every corner tells a story.",
    "FR": "France enchants with its world-class cuisine, iconic landmarks, and unparalleled art scene. From the Eiffel Tower's iron lace to the lavender fields of Provence, France is a feast for all the senses.",
    "IT": "Italy is an open-air museum where Roman ruins stand beside Renaissance masterpieces. Passionate food, dramatic landscapes, and a culture steeped in beauty make it one of the world's most beloved destinations.",
    "ES": "Spain pulses with flamenco rhythms, vibrant festivals, and architectural marvels. Its diverse regions each offer a distinct flavour — from Barcelona's Gaudí to the Alhambra of Granada.",
    "JP": "Japan is a captivating contrast of ancient tradition and hyper-modern innovation. Cherry blossoms, samurai history, bullet trains, and Michelin-starred ramen make it utterly unique.",
    "US": "The United States spans a continent of extremes — from the skyscrapers of New York to the Grand Canyon's ancient silence, from Hollywood glamour to Appalachian wilderness.",
    "GB": "Great Britain blends royal pageantry with cutting-edge culture. Explore Stonehenge's mysteries, London's world-class museums, and the rugged beauty of the Scottish Highlands.",
    "DE": "Germany combines fairy-tale castles, dark forests, and engineering excellence with a vibrant contemporary arts scene and some of Europe's finest beer culture.",
    "PT": "Portugal surprises with its warm people, melancholic fado music, and extraordinary seafood. From Lisbon's tiled azulejo facades to the Douro valley vineyards, it is Europe's most underrated gem.",
    "AU": "Australia is a land of extraordinary contrasts — the ochre outback of Uluru, the Great Barrier Reef's kaleidoscopic marine life, and buzzing cities like Sydney and Melbourne.",
    "NZ": "New Zealand's dramatic scenery made it Middle Earth on screen and an adventure-sports capital in reality. Maori culture, geothermal wonders, and pristine wilderness await.",
    "EG": "Egypt is home to one of the world's oldest civilisations. The Pyramids of Giza, the Nile's timeless flow, and the treasures of Luxor continue to awe millennia on.",
    "CN": "China's sheer scale astonishes: from the Great Wall snaking across mountain ridges to the ultramodern skylines of Shanghai and the karst peaks of Guilin.",
    "IN": "India is a sensory explosion — ancient temples, vibrant festivals, epic trains, and flavours that range from fiery Rajasthani to delicate Keralan.",
    "BR": "Brazil bursts with the energy of Carnival, the biodiversity of the Amazon, the beaches of Rio de Janeiro, and the modernist architecture of Brasília.",
    "TH": "Thailand dazzles with ornate golden temples, pristine island beaches, bustling night markets, and a cuisine of complex harmonious flavours.",
    "TR": "Turkey straddles two continents, blending Byzantine grandeur, Ottoman mosques, Cappadocian fairy chimneys, and sun-soaked Aegean coastlines.",
    "MA": "Morocco enchants with its labyrinthine medinas, Saharan dunes, Atlas mountain villages, and a spice-perfumed cuisine that lingers long after you leave.",
    "NO": "Norway dazzles with the Northern Lights, breathtaking fjords, and the midnight sun. Its Viking heritage and pristine wilderness make it one of the world's most dramatic landscapes.",
    "ZA": "South Africa is the Rainbow Nation — a land of extraordinary wildlife, dramatic coastlines, vibrant townships, and a complex, compelling history.",
    "CY": "Cyprus is a sun-soaked island with 9,000 years of history — Aphrodite's birthplace, crusader castles, and turquoise waters make it the Mediterranean's most storied gem.",
    "CH": "Switzerland is a land of dramatic Alpine peaks, pristine lakes, and meticulous craftsmanship. Whether skiing in Zermatt or cruising Lake Geneva, it defines natural grandeur.",
    "NL": "The Netherlands charms with its canal-laced cities, tulip-carpeted fields, and world-class art museums. Amsterdam's Golden Age architecture and cycling culture are iconic.",
    "AT": "Austria's imperial heritage lives on in Vienna's grand coffeehouses, Mozart's birthplace in Salzburg, and the Alps that inspired The Sound of Music.",
    "CA": "Canada's vastness encompasses Rocky Mountain grandeur, multicultural cities, and the majestic Aurora Borealis. It is one of the world's most welcoming and naturally spectacular nations.",
    "MX": "Mexico captivates with ancient Aztec pyramids, colonial silver cities, turquoise Caribbean beaches, and a cuisine so rich it holds UNESCO heritage status.",
    "AR": "Argentina stretches from the lunar landscapes of Patagonia to the sultry milongas of Buenos Aires. World-class wine, steak, and passion define the land of Borges and Messi.",
    "SE": "Sweden offers design innovation, deep forests, and a progressive society. From Stockholm's islands to Lapland's reindeer, it balances nature and urbanity effortlessly.",
    "DK": "Denmark leads in happiness, design, and gastronomy. Copenhagen's Noma restaurant redefined world cuisine, while Tivoli and the Little Mermaid delight visitors.",
    "FI": "Finland is a land of a thousand lakes, saunas, and the aurora borealis. It consistently ranks as the world's happiest country and a design powerhouse.",
]

private let landmarkImages: [String: String] = [
    "GR": "https://upload.wikimedia.org/wikipedia/commons/thumb/d/da/The_Parthenon_in_Athens.jpg/1280px-The_Parthenon_in_Athens.jpg",
    "IT": "https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/Colosseo_2020.jpg/1280px-Colosseo_2020.jpg",
    "ES": "https://upload.wikimedia.org/wikipedia/commons/thumb/5/5c/Sagrada_Familia_01.jpg/1024px-Sagrada_Familia_01.jpg",
    "JP": "https://upload.wikimedia.org/wikipedia/commons/thumb/1/16/Senso-ji_Temple_at_night.jpg/1280px-Senso-ji_Temple_at_night.jpg",
    "US": "https://upload.wikimedia.org/wikipedia/commons/thumb/a/af/Grand_Canyon_Horse_Shoe_Bend_MC.jpg/1280px-Grand_Canyon_Horse_Shoe_Bend_MC.jpg",
    "GB": "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d3/Big_Ben_2023.jpg/800px-Big_Ben_2023.jpg",
    "DE": "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e3/Neuschwanstein_Castle_Schwangau_Germany.jpg/1280px-Neuschwanstein_Castle_Schwangau_Germany.jpg",
    "PT": "https://upload.wikimedia.org/wikipedia/commons/thumb/5/52/Lisbon_%2836831759524%29.jpg/1280px-Lisbon_%2836831759524%29.jpg",
    "AU": "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a0/Sydney_Australia._(21339175489).jpg/1280px-Sydney_Australia._(21339175489).jpg",
    "NZ": "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f6/Milford_Sound_reflection.jpg/1280px-Milford_Sound_reflection.jpg",
    "EG": "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e3/Kheops-Pyramid.jpg/1280px-Kheops-Pyramid.jpg",
    "CN": "https://upload.wikimedia.org/wikipedia/commons/thumb/1/10/20090529_great_wall_8218.jpg/1280px-20090529_great_wall_8218.jpg",
    "IN": "https://upload.wikimedia.org/wikipedia/commons/thumb/b/bd/Taj_Mahal%2C_Agra%2C_India_edit3.jpg/1280px-Taj_Mahal%2C_Agra%2C_India_edit3.jpg",
    "BR": "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4f/Christ_the_Redeemer_-_Cristo_Redentor.jpg/800px-Christ_the_Redeemer_-_Cristo_Redentor.jpg",
    "TH": "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a0/Wat_Phra_Kaew%2C_2011.jpg/1280px-Wat_Phra_Kaew%2C_2011.jpg",
    "TR": "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f4/Blue-mosque-1920.jpg/1280px-Blue-mosque-1920.jpg",
    "MA": "https://upload.wikimedia.org/wikipedia/commons/thumb/2/27/Marrakesh_Djemaa_el_Fna_square.jpg/1280px-Marrakesh_Djemaa_el_Fna_square.jpg",
    "NO": "https://upload.wikimedia.org/wikipedia/commons/thumb/1/1e/Geiranger_fjord%2C_Norway.jpg/1280px-Geiranger_fjord%2C_Norway.jpg",
    "ZA": "https://upload.wikimedia.org/wikipedia/commons/thumb/1/10/Cape_Town_from_Table_Mountain.jpg/1280px-Cape_Town_from_Table_Mountain.jpg",
    "FR": "https://upload.wikimedia.org/wikipedia/commons/thumb/a/af/Tour_eiffel_at_sunrise_from_the_trocadero.jpg/800px-Tour_eiffel_at_sunrise_from_the_trocadero.jpg",
    "CH": "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8b/Matterhorn_from_Domh%C3%BCtte_-_2012-09-07_-_Front.jpg/1280px-Matterhorn_from_Domh%C3%BCtte_-_2012-09-07_-_Front.jpg",
    "NL": "https://upload.wikimedia.org/wikipedia/commons/thumb/2/20/Amsterdam_-_Rijksmuseum_-_panoramio_-_Nikolai_Karaneschev.jpg/1280px-Amsterdam_-_Rijksmuseum_-_panoramio_-_Nikolai_Karaneschev.jpg",
    "AT": "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4e/Schloss_Sch%C3%B6nbrunn_Wien_2014_%2810%29.jpg/1280px-Schloss_Sch%C3%B6nbrunn_Wien_2014_%2810%29.jpg",
    "CA": "https://upload.wikimedia.org/wikipedia/commons/thumb/9/9f/BanffNationalPark.jpg/1280px-BanffNationalPark.jpg",
    "MX": "https://upload.wikimedia.org/wikipedia/commons/thumb/9/95/Teotihuac%C3%A1n%2C_M%C3%A9xico%2C_2013-10-13%2C_DD_91.JPG/1280px-Teotihuac%C3%A1n%2C_M%C3%A9xico%2C_2013-10-13%2C_DD_91.JPG",
    "CY": "https://upload.wikimedia.org/wikipedia/commons/thumb/4/46/Paphos-coastline.jpg/1280px-Paphos-coastline.jpg",
]

// MARK: - Main View

struct CountryDetailPage: View {
    @ObservedObject var country: Country
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @State private var currentStatus: TravelStatus
    @State private var showAddRegion = false
    @State private var attractionSearch = ""
    @State private var citySearch = ""
    @State private var selectedTab = 0
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isImportingPhotos = false

    init(country: Country) {
        self.country = country
        _currentStatus = State(initialValue: TravelStatus(rawValue: country.status) ?? .none)
    }

    private var iso: String { country.isoCode ?? "" }
    private var description: String {
        countryDescriptions[iso] ?? "A fascinating destination with a rich culture, stunning landscapes, and memorable experiences waiting to be discovered."
    }
    private var landmarkURL: URL? {
        guard let s = landmarkImages[iso] else { return nil }
        return URL(string: s)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    landmarkHero
                    VStack(spacing: 20) {
                        countryHeaderCard
                        statusBar
                        tabSelector
                        tabContent
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .top)

            // Floating close button
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .padding(.leading, 16).padding(.top, 56)
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showAddRegion) {
            AddPlaceSheet(title: "Add Region", locationHint: country.name ?? "") { name in
                let r = Region(context: ctx); r.id = UUID()
                r.name = name; r.status = TravelStatus.none.rawValue; r.country = country
                try? ctx.save()
            }
        }
    }

    // MARK: - Landmark Hero

    private var landmarkHero: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                Group {
                    if let url = landmarkURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFill()
                                    .frame(width: geo.size.width, height: 320).clipped()
                            default:
                                fallbackGradient.overlay(
                                    phase == .empty ? AnyView(ProgressView().tint(.white)) : AnyView(EmptyView())
                                )
                            }
                        }
                    } else {
                        fallbackGradient
                    }
                }
                .frame(width: geo.size.width, height: 320)
            }
            .frame(height: 320)

            LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
                .frame(height: 200)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(flagEmoji(for: iso)).font(.system(size: 56)).shadow(color: .black.opacity(0.4), radius: 4)
                    Text(country.name ?? "")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4)
                    if let continent = country.continent {
                        Label(continent, systemImage: "globe")
                            .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Your rating").font(.caption2).foregroundStyle(.white.opacity(0.6))
                    HStack(spacing: 3) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: Float(i) <= country.rating ? "star.fill" : "star")
                                .font(.system(size: 15))
                                .foregroundStyle(Float(i) <= country.rating ? .yellow : .white.opacity(0.4))
                                .onTapGesture { country.rating = Float(i); try? ctx.save() }
                        }
                    }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
    }

    private var fallbackGradient: some View {
        LinearGradient(colors: [currentStatus.color.opacity(0.8), currentStatus.color.opacity(0.3)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Header card

    private var countryHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                let photosCount = (country.photos as? Set<TravelPhoto> ?? []).count
                let citiesCount = (country.regions as? Set<Region> ?? [])
                    .flatMap { ($0.cities as? Set<City> ?? []) }.count
                HStack(spacing: 12) {
                    if citiesCount > 0 {
                        Label("\(citiesCount) cities", systemImage: "building.2.fill")
                            .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    }
                    if photosCount > 0 {
                        Label("\(photosCount) photos", systemImage: "photo.fill")
                            .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if currentStatus != .none {
                    HStack(spacing: 5) {
                        Image(systemName: currentStatus.icon).font(.caption.weight(.bold))
                        Text(currentStatus.label).font(.caption.weight(.bold))
                    }
                    .foregroundStyle(currentStatus.color)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(currentStatus.color.opacity(0.12), in: Capsule())
                }
            }
            Divider()
            Text(description)
                .font(.subheadline).foregroundStyle(.secondary).lineSpacing(4)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.top, -24)
        .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 0) {
            ForEach(TravelStatus.allCases, id: \.id) { status in
                Button {
                    withAnimation(.spring(response: 0.25)) {
                        currentStatus = status
                        country.status = status.rawValue
                        try? ctx.save()
                        NotificationCenter.default.post(name: .countryStatusChanged,
                            object: nil, userInfo: ["isoCode": iso])
                    }
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(currentStatus == status ? status.color : Color(.secondarySystemFill))
                                .frame(width: 44, height: 44)
                                .shadow(color: currentStatus == status ? status.color.opacity(0.4) : .clear, radius: 6)
                            Image(systemName: status.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(currentStatus == status ? .white : .secondary)
                        }
                        Text(status == .none ? "None" : status.label)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(currentStatus == status ? status.color : .secondary)
                            .lineLimit(2).multilineTextAlignment(.center).frame(width: 54)
                    }
                    .frame(maxWidth: .infinity)
                    .scaleEffect(currentStatus == status ? 1.06 : 1.0)
                    .animation(.spring(response: 0.2), value: currentStatus)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 14).padding(.horizontal, 8)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Tab selector

    private var tabSelector: some View {
        let tabs = ["Overview", "Places", "Photos"]
        return HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { i in
                Button {
                    withAnimation(.spring(response: 0.3)) { selectedTab = i }
                } label: {
                    Text(tabs[i])
                        .font(.subheadline.weight(selectedTab == i ? .bold : .medium))
                        .foregroundStyle(selectedTab == i ? .primary : .secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .background(alignment: .bottom) {
            GeometryReader { geo in
                let w = geo.size.width / CGFloat(tabs.count)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary)
                    .frame(width: w * 0.45, height: 3)
                    .offset(x: w * CGFloat(selectedTab) + w * 0.275)
                    .animation(.spring(response: 0.3), value: selectedTab)
            }
            .frame(height: 3)
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0: overviewTab
        case 1: placesTab
        case 2: photosTab
        default: overviewTab
        }
    }

    // MARK: - Overview tab

    private var overviewTab: some View {
        VStack(spacing: 16) {
            if currentStatus != .none { datesCard }
            notesCard
        }
    }

    private var datesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(currentStatus == .livedIn ? "Residence Period" : "Visit Dates", systemImage: "calendar")
                .font(.subheadline.weight(.semibold))
            DateRow(label: currentStatus == .livedIn ? "Moved In" : "First Visit",
                    date: Binding(get: { country.firstVisitDate }, set: { country.firstVisitDate = $0; try? ctx.save() }))
            Divider()
            DateRow(label: currentStatus == .livedIn ? "Moved Out" : "Last Visit",
                    date: Binding(get: { country.lastVisitDate }, set: { country.lastVisitDate = $0; try? ctx.save() }))
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Notes & Memories", systemImage: "note.text").font(.subheadline.weight(.semibold))
            TextEditor(text: Binding(
                get: { country.notes ?? "" },
                set: { country.notes = $0.isEmpty ? nil : $0; try? ctx.save() }
            ))
            .font(.subheadline).frame(minHeight: 90)
            .scrollContentBackground(.hidden)
            .padding(10)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Places tab

    private var placesTab: some View {
        VStack(spacing: 16) {
            citiesSection
            attractionsSection
        }
    }

    private var citiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Cities", systemImage: "building.2.fill").font(.subheadline.weight(.bold))
                Spacer()
                Button { showAddRegion = true } label: {
                    Image(systemName: "plus.circle.fill").foregroundStyle(.tint).font(.title3)
                }
            }
            searchBar(text: $citySearch, placeholder: "Search cities…")

            let allCities: [City] = (country.regions as? Set<Region> ?? [])
                .sorted { ($0.name ?? "") < ($1.name ?? "") }
                .flatMap { ($0.cities as? Set<City> ?? []).sorted { ($0.name ?? "") < ($1.name ?? "") } }
            let filtered = citySearch.isEmpty ? allCities : allCities.filter {
                ($0.name ?? "").localizedCaseInsensitiveContains(citySearch)
            }

            if allCities.isEmpty {
                emptyPlaceholder(icon: "building.2", text: "No cities yet", sub: "Tap + to add regions and cities")
            } else if filtered.isEmpty {
                emptyPlaceholder(icon: "magnifyingglass", text: "No results", sub: "Try a different search term")
            } else {
                VStack(spacing: 8) {
                    ForEach(filtered, id: \.id) { city in CityDetailRow(city: city) }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var attractionsSection: some View {
        let allAttractions: [Attraction] = (country.regions as? Set<Region> ?? [])
            .flatMap { ($0.cities as? Set<City> ?? []) }
            .flatMap { ($0.attractions as? Set<Attraction> ?? []) }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
        let filtered = attractionSearch.isEmpty ? allAttractions : allAttractions.filter {
            ($0.name ?? "").localizedCaseInsensitiveContains(attractionSearch)
        }
        let visitedCount = allAttractions.filter { TravelStatus(rawValue: $0.status) == .visited }.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Attractions", systemImage: "mappin.and.ellipse").font(.subheadline.weight(.bold))
                Spacer()
                if !allAttractions.isEmpty {
                    Text("\(visitedCount)/\(allAttractions.count)")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
            }

            searchBar(text: $attractionSearch, placeholder: "Search attractions…")

            if !allAttractions.isEmpty {
                let progress = allAttractions.isEmpty ? 0.0 : Double(visitedCount) / Double(allAttractions.count)
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.15)).frame(height: 6)
                            Capsule()
                                .fill(LinearGradient(colors: [.teal, .blue], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * progress, height: 6)
                                .animation(.spring(response: 0.5), value: progress)
                        }
                    }
                    .frame(height: 6)
                    Text("\(Int(progress * 100))% explored").font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)
            }

            if allAttractions.isEmpty {
                emptyPlaceholder(icon: "mappin.circle", text: "No attractions yet", sub: "Add cities first, then add attractions inside them")
            } else if filtered.isEmpty {
                emptyPlaceholder(icon: "magnifyingglass", text: "No results", sub: "Try a different search term")
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(filtered, id: \.id) { attr in FancyAttractionRow(attraction: attr) }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Photos tab

    private var photosTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            PhotosPicker(selection: $selectedItems, maxSelectionCount: 50, matching: .images) {
                HStack {
                    Image(systemName: "photo.badge.plus.fill").font(.title3).foregroundStyle(.white)
                    Text("Import Photos").font(.subheadline.weight(.bold)).foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(
                    LinearGradient(colors: [.blue, .teal], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 14)
                )
            }
            .onChange(of: selectedItems) { _, items in Task { await importPhotos(items) } }

            if isImportingPhotos {
                HStack { Spacer(); ProgressView("Importing…").font(.caption); Spacer() }.padding(.vertical, 8)
            }

            let photos = (country.photos as? Set<TravelPhoto> ?? [])
                .sorted { ($0.takenDate ?? .distantPast) > ($1.takenDate ?? .distantPast) }

            if photos.isEmpty {
                emptyPlaceholder(icon: "photo.on.rectangle.angled", text: "No photos yet",
                                  sub: "Import photos to build your visual travel diary").padding(.top, 8)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 4)], spacing: 4) {
                    ForEach(photos, id: \.id) { photo in
                        PhotoGridCell(photo: photo) { ctx.delete(photo); try? ctx.save() }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Photo import

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        await MainActor.run { isImportingPhotos = true }
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let _ = UIImage(data: data) else { continue }
            let exif = EXIFReader.read(from: data)
            let photo = TravelPhoto(context: ctx)
            photo.id = UUID(); photo.imageData = data
            photo.takenDate = exif.dateTaken
            photo.latitude = exif.latitude ?? 0; photo.longitude = exif.longitude ?? 0
            photo.country = country
            try? ctx.save()
        }
        await MainActor.run { isImportingPhotos = false; selectedItems = [] }
    }

    // MARK: - Reusable subviews

    private func searchBar(text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.subheadline)
            TextField(placeholder, text: text).font(.subheadline)
            if !text.wrappedValue.isEmpty {
                Button { text.wrappedValue = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
    }

    private func emptyPlaceholder(icon: String, text: String, sub: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 32)).foregroundStyle(.tertiary)
            Text(text).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            Text(sub).font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 24)
    }

    private func flagEmoji(for iso: String) -> String {
        guard iso.count == 2 else { return "🏳️" }
        let base: UInt32 = 127397; var result = ""
        for scalar in iso.uppercased().unicodeScalars {
            guard let s = Unicode.Scalar(base + scalar.value) else { continue }
            result.append(Character(s))
        }
        return result.isEmpty ? "🏳️" : result
    }
}

// MARK: - City detail row

struct CityDetailRow: View {
    @ObservedObject var city: City
    @Environment(\.managedObjectContext) private var ctx
    @State private var expanded = false
    @State private var showAddAttraction = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.28)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill((TravelStatus(rawValue: city.status)?.color ?? .secondary).opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: TravelStatus(rawValue: city.status)?.icon ?? "circle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(TravelStatus(rawValue: city.status)?.color ?? .secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(city.name ?? "City").font(.subheadline.weight(.semibold))
                        let n = (city.attractions as? Set<Attraction> ?? []).count
                        if n > 0 { Text("\(n) attractions").font(.caption2).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        ForEach([TravelStatus.none, .wantToVisit, .visited, .livedIn], id: \.id) { s in
                            Button { city.status = s.rawValue; try? ctx.save() } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: s.icon).font(.caption2)
                                    Text(s == .none ? "None" : s.label).font(.caption2.weight(.medium))
                                }
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(Capsule().fill(TravelStatus(rawValue: city.status) == s
                                    ? s.color.opacity(0.18) : Color(.systemFill)))
                                .foregroundStyle(TravelStatus(rawValue: city.status) == s ? s.color : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    let attractions = (city.attractions as? Set<Attraction> ?? [])
                        .sorted { ($0.name ?? "") < ($1.name ?? "") }
                    ForEach(attractions, id: \.id) { attr in
                        FancyAttractionRow(attraction: attr).padding(.leading, 4)
                    }
                    Button { showAddAttraction = true } label: {
                        Label("Add Attraction", systemImage: "plus")
                            .font(.caption.weight(.semibold)).foregroundStyle(.tint)
                    }
                }
                .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 6)
                .sheet(isPresented: $showAddAttraction) {
                    AddPlaceSheet(
                        title: "Add Attraction",
                        locationHint: [city.name, city.region?.country?.name].compactMap { $0 }.joined(separator: ", ")
                    ) { name in
                        let a = Attraction(context: ctx); a.id = UUID()
                        a.name = name; a.status = TravelStatus.none.rawValue; a.city = city
                        try? ctx.save()
                    }
                }
            }
        }
    }
}

// MARK: - Fancy Attraction Row

struct FancyAttractionRow: View {
    @ObservedObject var attraction: Attraction
    @Environment(\.managedObjectContext) private var ctx
    private var isVisited: Bool { TravelStatus(rawValue: attraction.status) == .visited }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(isVisited ? .teal : Color(.systemGray3))
            Text(attraction.name ?? "Attraction")
                .font(.subheadline.weight(isVisited ? .medium : .regular))
                .foregroundStyle(isVisited ? .primary : .secondary)
            Spacer()
            Button {
                attraction.status = (isVisited ? TravelStatus.none : .visited).rawValue
                try? ctx.save()
            } label: {
                ZStack {
                    Circle().fill(isVisited ? Color.teal.opacity(0.15) : Color(.systemFill)).frame(width: 30, height: 30)
                    Image(systemName: isVisited ? "checkmark" : "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isVisited ? .teal : .secondary)
                }
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.2), value: isVisited)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Color(.tertiarySystemFill).opacity(isVisited ? 0.8 : 0.4),
                    in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Photo grid cell

struct PhotoGridCell: View {
    let photo: TravelPhoto
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let data = photo.imageData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 100, height: 100).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8).fill(Color(.systemFill))
                    .frame(width: 100, height: 100)
                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
            }
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill").font(.system(size: 18))
                    .foregroundStyle(.white).background(Color.black.opacity(0.45), in: Circle())
            }
            .offset(x: 4, y: -4)
        }
        .contextMenu {
            Button(role: .destructive, action: onDelete) { Label("Delete Photo", systemImage: "trash") }
        }
    }
}

// MARK: - StatusChip (kept for compatibility)

struct StatusChip: View {
    let status: TravelStatus
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    Circle().fill(isSelected ? status.color : Color(.secondarySystemFill)).frame(width: 40, height: 40)
                    Image(systemName: status.icon).font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .secondary)
                }
                Text(status == .none ? "None" : status.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isSelected ? status.color : .secondary)
                    .lineLimit(2).multilineTextAlignment(.center).frame(width: 56)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(.spring(response: 0.25), value: isSelected)
    }
}

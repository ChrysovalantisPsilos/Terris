// FlightTrackerView.swift — Flighty-style flight log
import SwiftUI
import CoreData
import MapKit

struct FlightTrackerView: View {
    @Environment(\.managedObjectContext) private var ctx
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Flight.departureDate, ascending: false)]
    ) private var flights: FetchedResults<Flight>

    @State private var showAddFlight = false
    @State private var selectedFlight: Flight?

    // MARK: - Computed stats
    private var totalFlights: Int { flights.count }
    private var totalKm: Double { flights.reduce(0) { $0 + $1.distanceKm } }
    private var uniqueAirports: Int {
        var iatas = Set<String>()
        for f in flights {
            if let d = f.departureAirport?.iata { iatas.insert(d) }
            if let a = f.arrivalAirport?.iata { iatas.insert(a) }
        }
        return iatas.count
    }
    private var uniqueCountries: Int {
        var countries = Set<String>()
        for f in flights {
            if let c = f.departureAirport?.countryISO { countries.insert(c) }
            if let c = f.arrivalAirport?.countryISO { countries.insert(c) }
        }
        return countries.count
    }
    private var earthCircumference: Double { 40_075 }
    private var earthCircles: Double { totalKm / earthCircumference }

    // Group flights by year
    private var flightsByYear: [(Int, [Flight])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: flights) { f -> Int in
            guard let d = f.departureDate else { return 0 }
            return cal.component(.year, from: d)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                statsHeader
                if flights.isEmpty {
                    emptyState
                } else {
                    flightList
                }
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Flights")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddFlight = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                }
            }
        }
        .sheet(isPresented: $showAddFlight) {
            AddFlightView()
        }
        .sheet(item: $selectedFlight) { flight in
            NavigationStack { FlightDetailView(flight: flight) }
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        VStack(spacing: 0) {
            // Top hero card
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "1a1a2e"), Color(hex: "16213e"), Color(hex: "0f3460")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea(edges: .top)

                VStack(spacing: 18) {
                    HStack(spacing: 0) {
                        Spacer()
                        planeIcon
                        Spacer()
                    }
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(totalFlights)")
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text(totalFlights == 1 ? "flight" : "flights")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.bottom, 6)
                    }
                    Text(String(format: "%.0f km · %.2f× around Earth", totalKm, max(0, earthCircles)))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.vertical, 28)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Stat pills
            HStack(spacing: 12) {
                FlightStatPill(value: "\(uniqueAirports)", label: "Airports", icon: "building.columns.fill", color: .blue)
                FlightStatPill(value: "\(uniqueCountries)", label: "Countries", icon: "globe", color: .green)
                FlightStatPill(value: String(format: "%.0f", totalKm), label: "km flown", icon: "arrow.left.and.right", color: .orange)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
        }
    }

    private var planeIcon: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 72, height: 72)
            Image(systemName: "airplane")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(-45))
        }
    }

    // MARK: - Flight List

    private var flightList: some View {
        VStack(spacing: 24) {
            ForEach(flightsByYear, id: \.0) { year, yearFlights in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(year == 0 ? "Unknown Year" : "\(year)")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                        Spacer()
                        Text("\(yearFlights.count) flight\(yearFlights.count == 1 ? "" : "s")")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 16)
                    }
                    ForEach(yearFlights, id: \.objectID) { flight in
                        FlightRowCard(flight: flight)
                            .onTapGesture { selectedFlight = flight }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    ctx.delete(flight)
                                    try? ctx.save()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)
            VStack(spacing: 8) {
                Text("No flights yet")
                    .font(.title3.bold())
                Text("Start logging your flights to see your personal flight stats and routes on the globe.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Button {
                showAddFlight = true
            } label: {
                Label("Log your first flight", systemImage: "plus")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding(.top, 40)
    }
}

// MARK: - Flight Row Card

struct FlightRowCard: View {
    let flight: Flight

    private var dep: Airport? { flight.departureAirport }
    private var arr: Airport? { flight.arrivalAirport }
    // Is currently airborne?
    private var isLive: Bool {
        guard let dep = flight.departureDate, let arr = flight.arrivalDate else { return false }
        let now = Date()
        return now >= dep && now <= arr
    }
    private var isUpcoming: Bool {
        guard let dep = flight.departureDate else { return false }
        let diff = dep.timeIntervalSinceNow
        return diff > 0 && diff < 86400
    }

    private var statusColor: Color {
        if isLive { return .green }
        switch flight.status {
        case "upcoming": return .blue
        case "cancelled": return .red
        default: return .secondary
        }
    }
    private var durationText: String {
        guard let dep = flight.departureDate, let arr = flight.arrivalDate else { return "" }
        let mins = Int(arr.timeIntervalSince(dep) / 60)
        guard mins > 0 else { return "" }
        return "\(mins / 60)h \(mins % 60)m"
    }
    private var dateText: String {
        guard let d = flight.departureDate else { return "" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: d)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                // Airline logo placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .frame(width: 44, height: 44)
                    Text(airlineInitials)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                // Route
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(dep?.iata ?? "???")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                        routeLine
                        Text(arr?.iata ?? "???")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                    }
                    HStack(spacing: 4) {
                        Text(dep?.city ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("→")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(arr?.city ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Right info
                VStack(alignment: .trailing, spacing: 4) {
                    if let fn = flight.flightNumber, !fn.isEmpty {
                        Text(fn)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    if !durationText.isEmpty {
                        Text(durationText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if flight.distanceKm > 0 {
                        Text(String(format: "%.0f km", flight.distanceKm))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider().padding(.horizontal, 14)

            HStack {
                Text(dateText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if isLive {
                    LiveBadge()
                } else if isUpcoming {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                        Text("Departing soon")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.blue.opacity(0.1), in: Capsule())
                } else {
                    if let cls = flight.seatClass, !cls.isEmpty {
                        Text(cls)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(seatClassColor(cls).opacity(0.15), in: Capsule())
                            .foregroundStyle(seatClassColor(cls))
                    }
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text((flight.status ?? "completed").capitalized)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(statusColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .padding(.horizontal, 16)
    }

    private var airlineInitials: String {
        let a = flight.airline ?? flight.flightNumber ?? "?"
        return String(a.prefix(2)).uppercased()
    }

    private var routeLine: some View {
        HStack(spacing: 3) {
            Circle().frame(width: 5, height: 5).foregroundStyle(.tertiary)
            Rectangle().frame(height: 1).foregroundStyle(.quaternary)
            Image(systemName: "airplane").font(.system(size: 9)).foregroundStyle(.secondary)
            Rectangle().frame(height: 1).foregroundStyle(.quaternary)
            Circle().frame(width: 5, height: 5).foregroundStyle(.tertiary)
        }
        .frame(width: 60)
    }

    private func seatClassColor(_ cls: String) -> Color {
        switch cls.lowercased() {
        case "first": return .purple
        case "business": return .blue
        case "premium economy": return .teal
        default: return .secondary
        }
    }
}

// MARK: - Stat Pill

struct FlightStatPill: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

// MARK: - Color hex helper (reuse if already defined elsewhere, otherwise keep)
private extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

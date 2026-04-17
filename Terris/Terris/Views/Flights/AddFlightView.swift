// AddFlightView.swift — add a new flight with airport autocomplete
import SwiftUI
import CoreData
struct AddFlightView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var flightNumber = ""
    @State private var airline = ""
    @State private var departureDate = Date()
    @State private var arrivalDate = Date().addingTimeInterval(3600 * 3)
    @State private var seatNumber = ""
    @State private var seatClass = "Economy"
    @State private var flightStatus = "completed"
    @State private var notes = ""
    @State private var rating: Int = 0

    // Airport search
    @State private var depQuery = ""
    @State private var arrQuery = ""
    @State private var depAirport: AirportRecord?
    @State private var arrAirport: AirportRecord?
    @State private var showDepSearch = false
    @State private var showArrSearch = false

    private let seatClasses = ["Economy", "Premium Economy", "Business", "First"]
    private let statuses = ["completed", "upcoming", "cancelled"]

    var body: some View {
        NavigationStack {
            Form {
                // Route section
                Section {
                    AirportPickerRow(
                        label: "From",
                        airport: depAirport,
                        systemImage: "airplane.departure"
                    ) { showDepSearch = true }

                    AirportPickerRow(
                        label: "To",
                        airport: arrAirport,
                        systemImage: "airplane.arrival"
                    ) { showArrSearch = true }
                } header: { Text("Route") }

                // Flight info
                Section {
                    HStack {
                        Image(systemName: "number").foregroundStyle(.secondary).frame(width: 22)
                        TextField("Flight number (e.g. BA123)", text: $flightNumber)
                    }
                    HStack {
                        Image(systemName: "building.2").foregroundStyle(.secondary).frame(width: 22)
                        TextField("Airline", text: $airline)
                    }
                } header: { Text("Flight Info") }

                // Dates
                Section {
                    DatePicker("Departure", selection: $departureDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Arrival", selection: $arrivalDate, in: departureDate..., displayedComponents: [.date, .hourAndMinute])
                } header: { Text("Times") }

                // Seat
                Section {
                    Picker("Class", selection: $seatClass) {
                        ForEach(seatClasses, id: \.self) { Text($0).tag($0) }
                    }
                    HStack {
                        Image(systemName: "chair").foregroundStyle(.secondary).frame(width: 22)
                        TextField("Seat number (e.g. 12A)", text: $seatNumber)
                    }
                } header: { Text("Seat") }

                // Status
                Section {
                    Picker("Status", selection: $flightStatus) {
                        ForEach(statuses, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: { Text("Status") }

                // Rating
                Section {
                    HStack {
                        Text("Rating")
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { i in
                                Image(systemName: i <= rating ? "star.fill" : "star")
                                    .foregroundStyle(i <= rating ? Color.yellow : Color.secondary)
                                    .font(.title3)
                                    .onTapGesture { rating = i == rating ? 0 : i }
                            }
                        }
                    }
                } header: { Text("Experience") }

                // Notes
                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                        .overlay(alignment: .topLeading) {
                            if notes.isEmpty {
                                Text("Notes, memories, delay info...")
                                    .foregroundStyle(.tertiary)
                                    .font(.body)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                } header: { Text("Notes") }
            }
            .navigationTitle("Log Flight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveFlight() }
                        .bold()
                        .disabled(depAirport == nil || arrAirport == nil)
                }
            }
            .sheet(isPresented: $showDepSearch) {
                AirportSearchSheet(query: $depQuery, selected: $depAirport)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showArrSearch) {
                AirportSearchSheet(query: $arrQuery, selected: $arrAirport)
                    .presentationDetents([.large])
            }
        }
    }

    // MARK: - Save

    private func saveFlight() {
        guard let depRec = depAirport, let arrRec = arrAirport else { return }

        let dep = findOrCreateAirport(depRec)
        let arr = findOrCreateAirport(arrRec)

        let flight = Flight(context: ctx)
        flight.id = UUID()
        flight.flightNumber = flightNumber.isEmpty ? nil : flightNumber.uppercased()
        flight.airline = airline.isEmpty ? nil : airline
        flight.departureDate = departureDate
        flight.arrivalDate = arrivalDate
        flight.seatNumber = seatNumber.isEmpty ? nil : seatNumber
        flight.seatClass = seatClass
        flight.status = flightStatus
        flight.notes = notes.isEmpty ? nil : notes
        flight.rating = Float(rating)
        flight.departureAirport = dep
        flight.arrivalAirport = arr
        flight.distanceKm = haversineKm(
            lat1: depRec.lat, lon1: depRec.lon,
            lat2: arrRec.lat, lon2: arrRec.lon
        )

        try? ctx.save()
        dismiss()
    }

    private func findOrCreateAirport(_ rec: AirportRecord) -> Airport {
        let req: NSFetchRequest<Airport> = Airport.fetchRequest()
        req.predicate = NSPredicate(format: "iata == %@", rec.iata)
        req.fetchLimit = 1
        if let existing = try? ctx.fetch(req).first { return existing }

        let a = Airport(context: ctx)
        a.id = UUID()
        a.iata = rec.iata
        a.icao = rec.icao
        a.name = rec.name
        a.city = rec.city
        a.countryISO = rec.countryISO
        a.latitude = rec.lat
        a.longitude = rec.lon
        return a
    }

    private func haversineKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat/2)*sin(dLat/2) +
                cos(lat1 * .pi/180)*cos(lat2 * .pi/180)*sin(dLon/2)*sin(dLon/2)
        return R * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

// MARK: - Airport Picker Row

struct AirportPickerRow: View {
    let label: String
    let airport: AirportRecord?
    let systemImage: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(.blue)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.caption).foregroundStyle(.secondary)
                    if let a = airport {
                        HStack(spacing: 6) {
                            Text(a.iata)
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                            Text("·")
                                .foregroundStyle(.tertiary)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(a.city)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(a.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    } else {
                        Text("Select airport")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary).font(.caption)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Airport Search Sheet

struct AirportSearchSheet: View {
    @Binding var query: String
    @Binding var selected: AirportRecord?
    @Environment(\.dismiss) private var dismiss

    private var results: [AirportRecord] {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            return Array(kAirportDatabase.prefix(40))
        }
        let q = query.lowercased()
        return kAirportDatabase.filter {
            $0.iata.lowercased().hasPrefix(q) ||
            $0.icao.lowercased().hasPrefix(q) ||
            $0.city.lowercased().contains(q) ||
            $0.name.lowercased().contains(q) ||
            $0.countryISO.lowercased() == q
        }
    }

    var body: some View {
        NavigationStack {
            List(results, id: \.iata) { airport in
                Button {
                    selected = airport
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                                .frame(width: 46, height: 36)
                            Text(airport.iata)
                                .font(.system(size: 13, weight: .black, design: .rounded))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(airport.city + ", " + airport.countryISO)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(airport.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search airports…")
            .navigationTitle("Select Airport")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

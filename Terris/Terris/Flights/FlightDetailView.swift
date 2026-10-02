// FlightDetailView.swift — full details for a single flight
import SwiftUI
import MapKit
import CoreData

struct FlightDetailView: View {
    @ObservedObject var flight: Flight
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false

    private var dep: Airport? { flight.departureAirport }
    private var arr: Airport? { flight.arrivalAirport }

    private var durationText: String {
        guard let d = flight.departureDate, let a = flight.arrivalDate else { return "—" }
        let mins = Int(a.timeIntervalSince(d) / 60)
        guard mins > 0 else { return "—" }
        return "\(mins / 60)h \(mins % 60)m"
    }
    private var statusColor: Color {
        switch flight.status {
        case "upcoming": return .blue
        case "cancelled": return .red
        default: return .green
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                routeHero
                arcMap
                detailGrid
                if let notes = flight.notes, !notes.isEmpty {
                    notesCard(notes)
                }
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(flight.flightNumber ?? "Flight")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showEdit = true } label: { Label("Edit", systemImage: "pencil") }
                    Divider()
                    Button(role: .destructive) {
                        ctx.delete(flight)
                        try? ctx.save()
                        dismiss()
                    } label: { Label("Delete Flight", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            Text("Edit coming soon").padding()
        }
    }

    // MARK: - Route Hero

    private var routeHero: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.13, blue: 0.25), Color(red: 0.06, green: 0.19, blue: 0.37)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(spacing: 16) {
                if let airline = flight.airline, !airline.isEmpty {
                    Text(airline)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                HStack(alignment: .center, spacing: 0) {
                    // Departure
                    VStack(spacing: 4) {
                        Text(dep?.iata ?? "???")
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text(dep?.city ?? "")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.65))
                        if let d = flight.departureDate {
                            Text(timeString(d))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Arc graphic
                    VStack(spacing: 6) {
                        Image(systemName: "airplane")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(-45))
                        Text(durationText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                        if flight.distanceKm > 0 {
                            Text(String(format: "%.0f km", flight.distanceKm))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Arrival
                    VStack(spacing: 4) {
                        Text(arr?.iata ?? "???")
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text(arr?.city ?? "")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.65))
                        if let a = flight.arrivalDate {
                            Text(timeString(a))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                // Status badge
                HStack(spacing: 6) {
                    Circle().fill(statusColor).frame(width: 7, height: 7)
                    Text((flight.status ?? "completed").capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.white.opacity(0.08), in: Capsule())
            }
            .padding(.vertical, 28)
            .padding(.horizontal, 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Arc Map

    @ViewBuilder
    private var arcMap: some View {
        if let depAirport = dep, let arrAirport = arr {
            let depCoord = CLLocationCoordinate2D(latitude: depAirport.latitude, longitude: depAirport.longitude)
            let arrCoord = CLLocationCoordinate2D(latitude: arrAirport.latitude, longitude: arrAirport.longitude)
            FlightArcMapView(departure: depCoord, arrival: arrCoord)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                .padding(.horizontal, 16)
        }
    }

    // MARK: - Detail Grid

    private var detailGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            FlightDetailCell(icon: "chair.fill", label: "Seat", value: seatText)
            FlightDetailCell(icon: "crown.fill", label: "Class", value: flight.seatClass ?? "Economy", color: seatClassColor)
            FlightDetailCell(icon: "calendar", label: "Date", value: dateText)
            FlightDetailCell(icon: "clock.fill", label: "Duration", value: durationText)
            FlightDetailCell(icon: "arrow.left.and.right", label: "Distance", value: distanceText)
            FlightDetailCell(icon: "star.fill", label: "Rating", value: ratingText, color: .yellow)
        }
        .padding(.horizontal, 16)
    }

    private var seatText: String {
        if let s = flight.seatNumber, !s.isEmpty { return s }
        return "—"
    }
    private var dateText: String {
        guard let d = flight.departureDate else { return "—" }
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
        return f.string(from: d)
    }
    private var distanceText: String {
        flight.distanceKm > 0 ? String(format: "%.0f km", flight.distanceKm) : "—"
    }
    private var ratingText: String {
        let r = Int(flight.rating)
        return r > 0 ? String(repeating: "★", count: r) + String(repeating: "☆", count: 5 - r) : "—"
    }
    private var seatClassColor: Color {
        switch (flight.seatClass ?? "").lowercased() {
        case "first": return .purple
        case "business": return .blue
        case "premium economy": return .teal
        default: return .secondary
        }
    }

    private func notesCard(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "note.text")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(notes)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .padding(.horizontal, 16)
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none
        return f.string(from: date)
    }
}

// MARK: - Detail Cell

struct FlightDetailCell: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color == .primary ? .blue : color)
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - Flight Arc Map (MKGeodesicPolyline)

struct FlightArcMapView: UIViewRepresentable {
    let departure: CLLocationCoordinate2D
    let arrival: CLLocationCoordinate2D

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.mapType = .hybridFlyover
        map.isUserInteractionEnabled = false
        map.delegate = context.coordinator

        // Add geodesic arc
        var coords = [departure, arrival]
        let polyline = MKGeodesicPolyline(coordinates: &coords, count: 2)
        map.addOverlay(polyline)

        // Add airport pins
        let depPin = MKPointAnnotation(); depPin.coordinate = departure
        let arrPin = MKPointAnnotation(); arrPin.coordinate = arrival
        map.addAnnotations([depPin, arrPin])

        // Fit map to show both airports with padding
        let region = regionFitting(departure, arrival)
        map.setRegion(region, animated: false)

        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKGeodesicPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.85)
                renderer.lineWidth = 2.5
                renderer.lineDashPattern = [6, 4]
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "airport")
            view.markerTintColor = UIColor.systemBlue
            view.glyphImage = UIImage(systemName: "airplane.circle.fill")
            view.canShowCallout = false
            return view
        }
    }

    private func regionFitting(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> MKCoordinateRegion {
        let midLat = (a.latitude + b.latitude) / 2
        let midLon = (a.longitude + b.longitude) / 2
        let spanLat = abs(a.latitude - b.latitude) * 1.5 + 10
        let spanLon = abs(a.longitude - b.longitude) * 1.5 + 10
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: midLat, longitude: midLon),
            span: MKCoordinateSpan(latitudeDelta: min(spanLat, 170), longitudeDelta: min(spanLon, 360))
        )
    }
}

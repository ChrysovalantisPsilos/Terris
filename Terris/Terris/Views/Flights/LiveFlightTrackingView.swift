// LiveFlightTrackingView.swift — Real-time flight tracking map
import SwiftUI
import MapKit
import CoreLocation

// MARK: - Main View

struct LiveFlightTrackingView: View {
    let flight: Flight
    @State private var service = FlightLiveTrackingService()
    @Environment(\.dismiss) private var dismiss

    private var dep: Airport? { flight.departureAirport }
    private var arr: Airport? { flight.arrivalAirport }
    private var flightNumber: String { flight.flightNumber ?? "" }

    var body: some View {
        ZStack {
            // Full-screen map
            LiveTrackingMapView(
                service: service,
                departure: dep.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) },
                arrival: arr.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            )
            .ignoresSafeArea()

            // Top overlay — dismiss + flight number
            VStack {
                HStack {
                    Button {
                        service.stopTracking()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    Spacer()
                    if service.isTracking {
                        LiveBadge()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                // Bottom stats card
                if let state = service.liveState {
                    liveStatsCard(state)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if let err = service.error {
                    errorCard(err)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    searchingCard
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4), value: service.liveState != nil)
            .animation(.spring(response: 0.4), value: service.error != nil)
        }
        .navigationBarHidden(true)
        .onAppear {
            if !flightNumber.isEmpty {
                service.startTracking(flightNumber: flightNumber)
            }
        }
        .onDisappear {
            service.stopTracking()
        }
    }

    // MARK: - Live Stats Card

    private func liveStatsCard(_ state: LiveFlightState) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(flightNumber)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                    HStack(spacing: 4) {
                        Image(systemName: state.climbIcon)
                            .font(.caption)
                        Text(state.climbStatus)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if let updated = service.lastUpdated {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Last updated")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(timeAgo(updated))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider().padding(.horizontal, 16)

            // Stats grid
            HStack(spacing: 0) {
                LiveStatItem(
                    icon: "location.north.fill",
                    label: "Altitude",
                    value: state.onGround ? "Ground" : String(format: "%.0f ft", state.altitudeFt),
                    color: .blue
                )
                Divider().frame(height: 40)
                LiveStatItem(
                    icon: "speedometer",
                    label: "Speed",
                    value: state.onGround ? "0 km/h" : String(format: "%.0f km/h", state.speedKmh),
                    color: .orange
                )
                Divider().frame(height: 40)
                LiveStatItem(
                    icon: "safari.fill",
                    label: "Heading",
                    value: String(format: "%.0f°", state.heading),
                    color: .green
                )
            }
            .padding(.vertical, 16)

            // Progress bar if we have dep/arr airports
            if let dep = dep, let arr = arr, !state.onGround {
                flightProgressBar(state: state, dep: dep, arr: arr)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 20, y: -4)
        .padding(.horizontal, 12)
        .padding(.bottom, 24)
    }

    private func flightProgressBar(state: LiveFlightState, dep: Airport, arr: Airport) -> some View {
        let depCoord = CLLocationCoordinate2D(latitude: dep.latitude, longitude: dep.longitude)
        let arrCoord = CLLocationCoordinate2D(latitude: arr.latitude, longitude: arr.longitude)
        let total = haversine(depCoord, arrCoord)
        let remaining = haversine(state.coordinate, arrCoord)
        let progress = max(0, min(1, 1.0 - (remaining / total)))

        return VStack(spacing: 8) {
            HStack {
                Text(dep.iata ?? "DEP")
                    .font(.caption.weight(.bold))
                Spacer()
                Text(String(format: "%.0f%% complete", progress * 100))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(arr.iata ?? "ARR")
                    .font(.caption.weight(.bold))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress, height: 6)

                    // Airplane marker
                    Image(systemName: "airplane")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(.blue, in: Circle())
                        .offset(x: max(0, geo.size.width * progress - 11))
                }
            }
            .frame(height: 22)
        }
    }

    // MARK: - Searching / Error Cards

    private var searchingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Searching for \(flightNumber)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Connecting to live tracking...")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(16)
        .background(Color.blue.opacity(0.85), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 24)
    }

    private func errorCard(_ error: TrackingError) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Tracking unavailable")
                    .font(.subheadline.weight(.semibold))
                Text(error.localizedDescription ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button("Retry") {
                service.startTracking(flightNumber: flightNumber)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.blue)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 24)
    }

    // MARK: - Helpers

    private func timeAgo(_ date: Date) -> String {
        let secs = Int(-date.timeIntervalSinceNow)
        if secs < 60 { return "\(secs)s ago" }
        return "\(secs / 60)m ago"
    }

    private func haversine(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let R = 6371.0
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let sinDLat = sin(dLat / 2)
        let sinDLon = sin(dLon / 2)
        let x = sinDLat * sinDLat + cos(a.latitude * .pi / 180) * cos(b.latitude * .pi / 180) * sinDLon * sinDLon
        return R * 2 * atan2(sqrt(x), sqrt(1 - x))
    }
}

// MARK: - Live Badge

struct LiveBadge: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(.red)
                .frame(width: 7, height: 7)
                .scaleEffect(pulse ? 1.3 : 1.0)
                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }
            Text("LIVE")
                .font(.caption.weight(.black))
                .tracking(1.5)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.red.opacity(0.25), in: Capsule())
        .overlay(Capsule().strokeBorder(.red.opacity(0.6), lineWidth: 1))
    }
}

// MARK: - Live Stat Item

struct LiveStatItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Live Tracking Map (UIViewRepresentable)

struct LiveTrackingMapView: UIViewRepresentable {
    let service: FlightLiveTrackingService
    let departure: CLLocationCoordinate2D?
    let arrival: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.mapType = .hybridFlyover
        map.isRotateEnabled = true
        map.isPitchEnabled = true
        map.delegate = context.coordinator
        context.coordinator.map = map

        // Add geodesic planned route arc
        if let dep = departure, let arr = arrival {
            var coords = [dep, arr]
            let arc = MKGeodesicPolyline(coordinates: &coords, count: 2)
            arc.title = "route"
            map.addOverlay(arc, level: .aboveRoads)

            // Add airport markers
            let depPin = MKPointAnnotation()
            depPin.coordinate = dep
            depPin.title = "DEP"
            let arrPin = MKPointAnnotation()
            arrPin.coordinate = arr
            arrPin.title = "ARR"
            map.addAnnotations([depPin, arrPin])

            // Set initial camera between airports
            let mid = CLLocationCoordinate2D(
                latitude: (dep.latitude + arr.latitude) / 2,
                longitude: (dep.longitude + arr.longitude) / 2
            )
            let dist = max(3_000_000, haversineMetres(dep, arr) * 1.5)
            let camera = MKMapCamera(lookingAtCenter: mid, fromDistance: dist, pitch: 0, heading: 0)
            map.setCamera(camera, animated: false)
        }

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.updatePlane(service: service)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        weak var map: MKMapView?
        private var planeAnnotation: PlaneAnnotation?
        private var trailPolyline: MKPolyline?

        func updatePlane(service: FlightLiveTrackingService) {
            guard let map = map else { return }
            guard let state = service.liveState else { return }

            // Animate plane marker to new position
            if let existing = planeAnnotation {
                UIView.animate(withDuration: 1.0) {
                    existing.coordinate = state.coordinate
                    existing.heading = state.heading
                    // Rotate annotation view
                    if let view = map.view(for: existing) as? PlaneAnnotationView {
                        view.updateHeading(state.heading)
                    }
                }
            } else {
                let annotation = PlaneAnnotation(coordinate: state.coordinate, heading: state.heading)
                map.addAnnotation(annotation)
                planeAnnotation = annotation
            }

            // Update trail polyline
            if let old = trailPolyline {
                map.removeOverlay(old)
            }
            if service.positionHistory.count >= 2 {
                var coords = service.positionHistory
                let trail = MKPolyline(coordinates: &coords, count: coords.count)
                trail.title = "trail"
                map.addOverlay(trail, level: .aboveRoads)
                trailPolyline = trail
            }
        }

        // MARK: Renderers

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKGeodesicPolyline {
                let r = MKPolylineRenderer(polyline: polyline)
                r.strokeColor = UIColor.systemBlue.withAlphaComponent(0.45)
                r.lineWidth = 2
                r.lineDashPattern = [6, 5]
                return r
            }
            if let polyline = overlay as? MKPolyline, polyline.title == "trail" {
                let r = MKPolylineRenderer(polyline: polyline)
                r.strokeColor = UIColor.systemCyan.withAlphaComponent(0.7)
                r.lineWidth = 3
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // MARK: Annotation views

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            if let plane = annotation as? PlaneAnnotation {
                let id = "plane"
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? PlaneAnnotationView)
                    ?? PlaneAnnotationView(annotation: plane, reuseIdentifier: id)
                view.annotation = plane
                view.updateHeading(plane.heading)
                return view
            }

            // Airport markers
            let id = "airport"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation
            view.markerTintColor = UIColor.systemBlue
            view.glyphImage = UIImage(systemName: "airplane.circle.fill")
            view.canShowCallout = false
            return view
        }
    }

    private func haversineMetres(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        let loc1 = CLLocation(latitude: a.latitude, longitude: a.longitude)
        let loc2 = CLLocation(latitude: b.latitude, longitude: b.longitude)
        return loc1.distance(from: loc2)
    }
}

// MARK: - Plane Annotation

class PlaneAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var heading: Double

    init(coordinate: CLLocationCoordinate2D, heading: Double) {
        self.coordinate = coordinate
        self.heading = heading
    }
}

class PlaneAnnotationView: MKAnnotationView {
    private let planeImageView = UIImageView()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        let config = UIImage.SymbolConfiguration(pointSize: 26, weight: .bold)
        let img = UIImage(systemName: "airplane", withConfiguration: config)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        planeImageView.image = img
        planeImageView.frame = CGRect(x: -16, y: -16, width: 32, height: 32)

        // Blue glowing circle behind plane
        let circle = UIView(frame: CGRect(x: -20, y: -20, width: 40, height: 40))
        circle.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
        circle.layer.cornerRadius = 20
        circle.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.6).cgColor
        circle.layer.borderWidth = 1.5

        addSubview(circle)
        addSubview(planeImageView)
        frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        canShowCallout = false

        // Pulse animation
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0; pulse.toValue = 1.3
        pulse.duration = 1.2; pulse.autoreverses = true; pulse.repeatCount = .infinity
        circle.layer.add(pulse, forKey: "pulse")
    }

    func updateHeading(_ heading: Double) {
        // MapKit north = up, airplane.fill default points right (+90°)
        let rad = CGFloat((heading - 90) * .pi / 180)
        planeImageView.transform = CGAffineTransform(rotationAngle: rad)
    }
}

// FlightLiveTrackingService.swift — Real-time flight position via OpenSky Network API
// OpenSky is free, no API key required. Docs: https://openskynetwork.github.io/opensky-api/rest.html

import Foundation
import CoreLocation
import Combine

// MARK: - Live Flight State

struct LiveFlightState {
    let callsign: String
    let latitude: Double
    let longitude: Double
    let altitude: Double      // metres (barometric)
    let velocity: Double      // m/s
    let heading: Double       // degrees true north
    let verticalRate: Double  // m/s positive = climbing
    let onGround: Bool
    let lastContact: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    var speedKmh: Double { velocity * 3.6 }
    var altitudeFt: Double { altitude * 3.28084 }

    var climbStatus: String {
        if onGround { return "On Ground" }
        if verticalRate > 2 { return "Climbing" }
        if verticalRate < -2 { return "Descending" }
        return "Cruise"
    }
    var climbIcon: String {
        if onGround { return "airplane.arrival" }
        if verticalRate > 2 { return "airplane.departure" }
        if verticalRate < -2 { return "airplane.arrival" }
        return "airplane"
    }
}

// MARK: - Tracking Error

enum TrackingError: LocalizedError {
    case flightNotFound(String)
    case networkError(Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .flightNotFound(let callsign):
            return "Flight \(callsign) not found in live data. It may not be airborne yet."
        case .networkError(let e):
            return "Network error: \(e.localizedDescription)"
        case .invalidResponse:
            return "Unexpected response from tracking server."
        }
    }
}

// MARK: - Service

@Observable
final class FlightLiveTrackingService {

    // Published state
    var liveState: LiveFlightState?
    var isTracking: Bool = false
    var error: TrackingError?
    var lastUpdated: Date?

    // Position history for trail
    var positionHistory: [CLLocationCoordinate2D] = []

    private var callsign: String = ""      // ICAO callsign (converted)
    private var originalInput: String = "" // original as entered by user
    private var timer: AnyCancellable?
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        session = URLSession(configuration: config)
    }

    // MARK: - IATA → ICAO airline code mapping
    // OpenSky uses ICAO callsigns (e.g. AEE127), not IATA (e.g. A3127)
    private static let iataToIcao: [String: String] = [
        "A3": "AEE", // Aegean Airlines
        "AA": "AAL", // American Airlines
        "AB": "BER", // Air Berlin
        "AC": "ACA", // Air Canada
        "AF": "AFR", // Air France
        "AY": "FIN", // Finnair
        "AZ": "AZA", // ITA Airways
        "BA": "BAW", // British Airways
        "BT": "BTI", // airBaltic
        "CA": "CCA", // Air China
        "CI": "CAL", // China Airlines
        "CX": "CPA", // Cathay Pacific
        "DE": "CFG", // Condor
        "DL": "DAL", // Delta Air Lines
        "EI": "EIN", // Aer Lingus
        "EK": "UAE", // Emirates
        "ET": "ETH", // Ethiopian Airlines
        "EW": "EWG", // Eurowings
        "EY": "ETD", // Etihad Airways
        "FI": "ICE", // Icelandair
        "FR": "RYR", // Ryanair
        "G3": "GLO", // Gol Linhas Aéreas
        "GF": "GFA", // Gulf Air
        "HA": "HAL", // Hawaiian Airlines
        "HV": "TRA", // Transavia
        "IB": "IBE", // Iberia
        "JL": "JAL", // Japan Airlines
        "JP": "ADR", // Adria Airways
        "JQ": "JST", // Jetstar
        "KE": "KAL", // Korean Air
        "KL": "KLM", // KLM
        "LA": "LAN", // LATAM
        "LH": "DLH", // Lufthansa
        "LO": "LOT", // LOT Polish Airlines
        "LX": "SWR", // Swiss
        "LY": "ELY", // El Al
        "MH": "MAS", // Malaysia Airlines
        "MS": "MSR", // EgyptAir
        "MU": "CES", // China Eastern
        "NH": "ANA", // All Nippon Airways
        "NZ": "ANZ", // Air New Zealand
        "OK": "CSA", // Czech Airlines
        "OS": "AUA", // Austrian Airlines
        "OZ": "AAR", // Asiana Airlines
        "PC": "PGT", // Pegasus Airlines
        "PK": "PIA", // Pakistan International Airlines
        "PS": "AUI", // Ukraine International Airlines
        "QF": "QFA", // Qantas
        "QR": "QTR", // Qatar Airways
        "RO": "ROT", // TAROM
        "S7": "SBI", // S7 Airlines
        "SK": "SAS", // Scandinavian Airlines
        "SN": "BEL", // Brussels Airlines
        "SQ": "SIA", // Singapore Airlines
        "SU": "AFL", // Aeroflot
        "SV": "SVA", // Saudia
        "TG": "THA", // Thai Airways
        "TK": "THY", // Turkish Airlines
        "TP": "TAP", // TAP Air Portugal
        "TU": "TAR", // Tunisair
        "U2": "EZY", // easyJet
        "UA": "UAL", // United Airlines
        "UL": "ALK", // SriLankan Airlines
        "UN": "TSO", // Transaero
        "US": "USA", // US Airways
        "UX": "AEA", // Air Europa
        "VN": "HVN", // Vietnam Airlines
        "VS": "VIR", // Virgin Atlantic
        "VY": "VLG", // Vueling
        "W6": "WZZ", // Wizz Air
        "WN": "SWA", // Southwest Airlines
        "WS": "WJA", // WestJet
        "X3": "TUI", // TUI fly
        "XQ": "SXS", // SunExpress
        "ZI": "AAF", // Aigle Azur
    ]

    /// Convert IATA flight number (e.g. "A3127") to ICAO callsign (e.g. "AEE127")
    private func toIcaoCallsign(_ input: String) -> String {
        let upper = input.uppercased().replacingOccurrences(of: " ", with: "")

        // Try 2-char IATA prefix first
        if upper.count >= 3 {
            let prefix2 = String(upper.prefix(2))
            if let icao = Self.iataToIcao[prefix2] {
                let number = String(upper.dropFirst(2))
                return icao + number
            }
        }

        // Try 1-char prefix (some carriers use single letter like "B" for Belavia)
        let prefix1 = String(upper.prefix(1))
        if let icao = Self.iataToIcao[prefix1] {
            let number = String(upper.dropFirst(1))
            return icao + number
        }

        // Already ICAO format or unknown — use as-is
        return upper
    }

    // MARK: - Start / Stop

    func startTracking(flightNumber: String) {
        let raw = flightNumber.uppercased().replacingOccurrences(of: " ", with: "")
        originalInput = raw
        // Convert IATA → ICAO callsign for OpenSky
        callsign = toIcaoCallsign(raw)

        isTracking = true
        error = nil
        positionHistory = []

        // Fetch immediately, then every 15 seconds
        Task { await fetchState() }
        timer = Timer.publish(every: 15, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.fetchState() }
            }
    }

    func stopTracking() {
        timer?.cancel()
        timer = nil
        isTracking = false
    }

    // MARK: - Fetch

    @MainActor
    private func fetchState() async {
        // OpenSky: filter by callsign
        // Pad callsign to 8 chars (OpenSky requirement)
        let paddedCallsign = callsign.padding(toLength: 8, withPad: " ", startingAt: 0)
        let encoded = paddedCallsign.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? callsign

        guard let url = URL(string: "https://opensky-network.org/api/states/all?callsign=\(encoded)") else { return }

        do {
            let (data, response) = try await session.data(from: url)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                error = .invalidResponse
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let states = json["states"] as? [[Any?]],
                  let stateVec = states.first
            else {
                // Also try broader callsign search (strip trailing spaces)
                await fetchBroadSearch()
                return
            }

            if let state = parseState(stateVec) {
                updateState(state)
            }

        } catch {
            self.error = .networkError(error)
        }
    }

    // Broad search — try without padding if padded callsign fails
    @MainActor
    private func fetchBroadSearch() async {
        guard let url = URL(string: "https://opensky-network.org/api/states/all") else { return }

        do {
            let (data, _) = try await session.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let states = json["states"] as? [[Any?]] else {
                error = .flightNotFound(callsign)
                return
            }

            // Find matching callsign (trimmed) — try ICAO and original IATA
            let match = states.first { vec in
                guard let cs = vec[1] as? String else { return false }
                let trimmed = cs.trimmingCharacters(in: .whitespaces).uppercased()
                return trimmed == callsign || trimmed == originalInput
            }

            if let stateVec = match, let state = parseState(stateVec) {
                updateState(state)
            } else {
                error = .flightNotFound(callsign)
            }
        } catch {
            self.error = .networkError(error)
        }
    }

    // MARK: - Parse OpenSky state vector
    // [icao24, callsign, origin_country, time_position, last_contact,
    //  longitude(5), latitude(6), baro_altitude(7), on_ground(8),
    //  velocity(9), true_track(10), vertical_rate(11), ...]

    private func parseState(_ v: [Any?]) -> LiveFlightState? {
        guard v.count >= 12 else { return nil }
        guard let cs   = v[1] as? String,
              let lon  = v[5] as? Double,
              let lat  = v[6] as? Double else { return nil }

        let alt  = (v[7]  as? Double) ?? 0
        let onG  = (v[8]  as? Bool)   ?? false
        let vel  = (v[9]  as? Double) ?? 0
        let hdg  = (v[10] as? Double) ?? 0
        let vr   = (v[11] as? Double) ?? 0
        let lc   = (v[4]  as? Double).map { Date(timeIntervalSince1970: $0) } ?? Date()

        return LiveFlightState(
            callsign: cs.trimmingCharacters(in: .whitespaces),
            latitude: lat,
            longitude: lon,
            altitude: alt,
            velocity: vel,
            heading: hdg,
            verticalRate: vr,
            onGround: onG,
            lastContact: lc
        )
    }

    private func updateState(_ state: LiveFlightState) {
        liveState = state
        lastUpdated = Date()
        error = nil

        // Append to trail (cap at 200 points)
        positionHistory.append(state.coordinate)
        if positionHistory.count > 200 {
            positionHistory.removeFirst()
        }
    }
}

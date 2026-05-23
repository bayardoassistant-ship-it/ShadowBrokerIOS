import Foundation
import Combine

/// Service for connecting to a ShadowBroker backend instance or public ADS-B sources.
/// Configure the baseURL to point to your self-hosted ShadowBroker (http://your-server:8000)
final class ShadowBrokerAPIService: ObservableObject {
    static let shared = ShadowBrokerAPIService()

    // MARK: - Configuration
    @Published var baseURL: String = "http://localhost:8000" // Change to your ShadowBroker instance
    @Published var connectionState: ConnectionState = .disconnected
    @Published var lastUpdate: Date?

    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()

    // For demo / fallback when no backend is available
    private let openSkyURL = "https://opensky-network.org/api/states/all"

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
    }

    // MARK: - Live Data Fetch (Primary: ShadowBroker backend)
    func fetchLiveData() async throws -> [Aircraft] {
        connectionState = .connecting

        // Try ShadowBroker first
        if let url = URL(string: "\(baseURL)/api/live-data/fast") {
            do {
                let (data, response) = try await session.data(from: url)

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    let aircraft = try parseShadowBrokerLiveData(data)
                    connectionState = .connected
                    lastUpdate = Date()
                    return aircraft
                }
            } catch {
                print("ShadowBroker backend unavailable: \(error). Falling back to OpenSky...")
            }
        }

        // Fallback to OpenSky public API (limited, no auth)
        return try await fetchFromOpenSky()
    }

    // MARK: - Parse ShadowBroker Response
    private func parseShadowBrokerLiveData(_ data: Data) throws -> [Aircraft] {
        // ShadowBroker returns a complex structure with flights + military + tracked info
        // For simplicity we decode a flattened view. In production you'd map the full schema.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        // Expecting something like { "flights": [...], "military": [...] }
        let response = try decoder.decode(LiveDataResponse.self, from: data)

        var aircraftList: [Aircraft] = []

        // Commercial / general flights
        if let flights = response.flights {
            for f in flights {
                guard let icao = f.icao24, let lat = f.lat, let lon = f.lon else { continue }

                let category = classifyAircraft(
                    callsign: f.callsign,
                    registration: f.reg,
                    aircraftType: f.type,
                    operator: f.op
                )

                let ac = Aircraft(
                    id: icao,
                    callsign: f.callsign?.trimmingCharacters(in: .whitespaces),
                    registration: f.reg,
                    operator: f.op,
                    aircraftType: f.type,
                    category: category,
                    tags: [],
                    latitude: lat,
                    longitude: lon,
                    altitude: f.alt,
                    speed: f.spd,
                    heading: f.hdg,
                    verticalRate: f.vr,
                    squawk: f.sqk,
                    origin: f.from,
                    destination: f.to,
                    isTracked: false,
                    trackedName: nil,
                    trackedCategory: nil,
                    country: f.country,
                    flag: f.flag,
                    militaryForce: nil,
                    isUAV: false,
                    uavType: nil,
                    wikiURL: nil,
                    emissions: nil,
                    isGPSJammed: false,
                    lastUpdated: Date()
                )
                aircraftList.append(ac)
            }
        }

        // Military enrichment
        if let military = response.military {
            for m in military {
                guard let icao = m.icao24, let lat = m.lat, let lon = m.lon else { continue }

                let category = classifyMilitary(
                    model: m.model ?? m.type ?? "",
                    callsign: m.callsign ?? "",
                    force: m.force
                )

                let ac = Aircraft(
                    id: icao,
                    callsign: m.callsign,
                    registration: nil,
                    operator: m.force,
                    aircraftType: m.model ?? m.type,
                    category: category,
                    tags: [],
                    latitude: lat,
                    longitude: lon,
                    altitude: m.alt,
                    speed: m.spd,
                    heading: m.hdg,
                    verticalRate: nil,
                    squawk: nil,
                    origin: nil,
                    destination: nil,
                    isTracked: category.priority < 5,
                    trackedName: m.force,
                    trackedCategory: "Military",
                    country: nil,
                    flag: nil,
                    militaryForce: m.force,
                    isUAV: m.isUAV ?? false,
                    uavType: m.uavType,
                    wikiURL: m.wikiURL,
                    emissions: nil,
                    isGPSJammed: false,
                    lastUpdated: Date()
                )
                aircraftList.append(ac)
            }
        }

        return aircraftList
    }

    // MARK: - OpenSky Fallback (Public, rate-limited)
    private func fetchFromOpenSky() async throws -> [Aircraft] {
        guard let url = URL(string: openSkyURL) else {
            throw URLError(.badURL)
        }

        let (data, _) = try await session.data(from: url)
        let decoder = JSONDecoder()

        struct OpenSkyResponse: Codable {
            let time: Int
            let states: [[JSONValue]]?
        }

        // OpenSky returns a very flat array — we do minimal parsing here
        let response = try decoder.decode(OpenSkyResponse.self, from: data)

        var result: [Aircraft] = []
        if let states = response.states {
            for state in states {
                // OpenSky array format: [icao24, callsign, origin_country, time_position, last_contact, lon, lat, baro_altitude, ...]
                guard state.count > 6,
                      let icao = state[0].stringValue,
                      let callsign = state[1].stringValue?.trimmingCharacters(in: .whitespaces),
                      let lon = state[5].doubleValue,
                      let lat = state[6].doubleValue else { continue }

                let alt = state.count > 7 ? state[7].doubleValue : nil
                let spd = state.count > 9 ? state[9].doubleValue : nil
                let hdg = state.count > 10 ? state[10].doubleValue : nil

                let category = classifyAircraft(callsign: callsign, registration: nil, aircraftType: nil, operator: nil)

                let ac = Aircraft(
                    id: icao,
                    callsign: callsign,
                    registration: nil,
                    operator: nil,
                    aircraftType: nil,
                    category: category,
                    tags: [],
                    latitude: lat,
                    longitude: lon,
                    altitude: alt,
                    speed: spd,
                    heading: hdg,
                    verticalRate: nil,
                    squawk: nil,
                    origin: nil,
                    destination: nil,
                    isTracked: false,
                    trackedName: nil,
                    trackedCategory: nil,
                    country: nil,
                    flag: nil,
                    militaryForce: nil,
                    isUAV: false,
                    uavType: nil,
                    wikiURL: nil,
                    emissions: nil,
                    isGPSJammed: false,
                    lastUpdated: Date(timeIntervalSince1970: TimeInterval(response.time))
                )
                result.append(ac)
            }
        }

        connectionState = .connected
        lastUpdate = Date()
        return result
    }

    // MARK: - Classification Helpers (mirrors ShadowBroker logic)
    private func classifyAircraft(callsign: String?, registration: String?, aircraftType: String?, operator: String?) -> AircraftCategory {
        let cs = callsign?.uppercased() ?? ""
        let reg = registration?.uppercased() ?? ""
        let op = operator?.uppercased() ?? ""

        // Presidential / Air Force One detection (from tracked_names.json)
        if cs.contains("AF1") || reg.contains("92-9000") || reg.contains("98-0002") || reg.contains("09-0017") {
            return .airForceOne
        }
        if cs.contains("AF2") || cs.contains("SAM") || reg.contains("98-0001") || reg.contains("99-0003") {
            return .presidential
        }

        // Billionaire / high-profile people (examples)
        let billionaireRegs = ["N628TS", "N8628", "N897GV", "N887GV", "N421AL", "N302AK"]
        if billionaireRegs.contains(reg) {
            return .billionaire
        }

        // Government / military callsigns
        if cs.hasPrefix("RCH") || cs.hasPrefix("QQ") || cs.hasPrefix("SAM") || op.contains("AIR FORCE") {
            return .military
        }

        if cs.hasPrefix("FORTE") || cs.hasPrefix("GHAWK") || cs.contains("REAPER") || cs.contains("GLOBALHAWK") {
            return .militaryISR
        }

        return .commercial
    }

    private func classifyMilitary(model: String, callsign: String, force: String?) -> AircraftCategory {
        let m = model.uppercased().replacingOccurrences(of: "-", with: "")
        let cs = callsign.uppercased()

        if m.contains("KC135") || m.contains("KC46") || m.contains("A330") {
            return .militaryTanker
        }
        if m.contains("F16") || m.contains("F35") || m.contains("F22") || m.contains("F15") || m.contains("SU27") {
            return .militaryFighter
        }
        if m.contains("B52") || m.contains("B1") || m.contains("B2") {
            return .militaryBomber
        }
        if m.contains("RQ4") || m.contains("MQ9") || m.contains("GLOBALHAWK") || cs.hasPrefix("FORTE") {
            return .militaryISR
        }
        if m.contains("C17") || m.contains("C130") || m.contains("C5") {
            return .militaryCargo
        }
        if cs.hasPrefix("FORTE") || cs.hasPrefix("GHAWK") || cs.hasPrefix("REAP") {
            return .militaryUAV
        }
        return .military
    }

    // MARK: - Tracked Names Loader (from ShadowBroker data/tracked_names.json)
    func loadTrackedNames() -> [TrackedEntity] {
        // In a real app you'd bundle the JSON or fetch /api/tracked-names
        // For now we return a curated subset matching the repo's spirit
        return [
            TrackedEntity(name: "United States of America 747/757", category: "Government", registrations: ["02-4452", "09-2017", "92-9000", "98-0002", "09-2016"]),
            TrackedEntity(name: "Elon Musk", category: "People", registrations: ["N628TS", "N8628", "N8628T", "N272BG"]),
            TrackedEntity(name: "Bill Gates", category: "People", registrations: ["N897GV", "N887GV", "N608GV"]),
            TrackedEntity(name: "Larry Ellison", category: "People", registrations: ["N817GS", "N417C"]),
            TrackedEntity(name: "Mark Cuban", category: "People", registrations: ["N921MT", "N718MC"]),
            TrackedEntity(name: "Government of Russia", category: "Government", registrations: ["RA-96024", "RA-96019"]),
            TrackedEntity(name: "Government of Saudi Arabia", category: "Government", registrations: ["HZ-SKY3", "HZ-HM65"]),
            TrackedEntity(name: "Royal Air Force", category: "Government", registrations: ["G-XATW", "ZZ336"])
        ]
    }
}

// Helper for decoding mixed-type OpenSky arrays
enum JSONValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let v = try? container.decode(String.self) {
            self = .string(v)
        } else if let v = try? container.decode(Int.self) {
            self = .int(v)
        } else if let v = try? container.decode(Double.self) {
            self = .double(v)
        } else if let v = try? container.decode(Bool.self) {
            self = .bool(v)
        } else {
            self = .null
        }
    }

    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }
    var doubleValue: Double? {
        if case .double(let d) = self { return d }
        if case .int(let i) = self { return Double(i) }
        return nil
    }
}

import Foundation
import CoreLocation

// MARK: - Aircraft Category
enum AircraftCategory: String, CaseIterable, Identifiable {
    case airForceOne = "Air Force One"
    case presidential = "Presidential"
    case military = "Military"
    case militaryTanker = "Tanker"
    case militaryISR = "ISR"
    case militaryFighter = "Fighter"
    case militaryBomber = "Bomber"
    case militaryCargo = "Cargo"
    case militaryUAV = "UAV"
    case billionaire = "Billionaire"
    case government = "Government"
    case commercial = "Commercial"
    case other = "Other"

    var id: String { rawValue }

    var color: String {
        switch self {
        case .airForceOne: return "FFD700"      // Gold
        case .presidential: return "FF6B6B"      // Red
        case .military: return "4ECDC4"          // Teal
        case .militaryTanker: return "FF8C42"    // Orange
        case .militaryISR: return "A855F7"       // Purple
        case .militaryFighter: return "EF4444"   // Bright Red
        case .militaryBomber: return "F97316"    // Dark Orange
        case .militaryCargo: return "84CC16"     // Lime
        case .militaryUAV: return "06B6D4"       // Cyan
        case .billionaire: return "10B981"       // Emerald
        case .government: return "3B82F6"        // Blue
        case .commercial: return "6B7280"        // Gray
        case .other: return "9CA3AF"             // Light Gray
        }
    }

    var icon: String {
        switch self {
        case .airForceOne: return "star.fill"
        case .presidential: return "crown.fill"
        case .military, .militaryTanker, .militaryISR, .militaryFighter, .militaryBomber, .militaryCargo: return "airplane"
        case .militaryUAV: return "antenna.radiowaves.left.and.right"
        case .billionaire: return "dollarsign.circle.fill"
        case .government: return "building.columns.fill"
        case .commercial: return "airplane.circle"
        case .other: return "questionmark.circle"
        }
    }

    var priority: Int {
        switch self {
        case .airForceOne: return 0
        case .presidential: return 1
        case .militaryISR: return 2
        case .militaryFighter: return 3
        case .militaryTanker: return 4
        case .militaryBomber: return 5
        case .militaryUAV: return 6
        case .militaryCargo: return 7
        case .military: return 8
        case .billionaire: return 9
        case .government: return 10
        case .commercial: return 11
        case .other: return 12
        }
    }
}

// MARK: - Aircraft Data Model
struct Aircraft: Identifiable, Equatable {
    let id: String                          // icao24 hex
    var icao24: String { id }
    var callsign: String?
    var registration: String?
    var `operator`: String?
    var aircraftType: String?
    var category: AircraftCategory
    var tags: [String]
    var latitude: Double
    var longitude: Double
    var altitude: Double?                   // feet
    var speed: Double?                      // knots
    var heading: Double?                    // degrees
    var verticalRate: Double?               // ft/min
    var squawk: String?
    var origin: String?
    var destination: String?
    var isTracked: Bool
    var trackedName: String?                // e.g. "Elon Musk", "Air Force One"
    var trackedCategory: String?            // e.g. "People", "Government"
    var country: String?
    var flag: String?
    var militaryForce: String?              // e.g. "USAF", "VKS"
    var isUAV: Bool
    var uavType: String?
    var wikiURL: String?
    var emissions: String?
    var isGPSJammed: Bool
    var lastUpdated: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var isHighlighted: Bool {
        category == .airForceOne || category == .presidential || category == .billionaire
    }

    static func == (lhs: Aircraft, rhs: Aircraft) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Tracked Entity
struct TrackedEntity: Identifiable, Codable {
    let id: String
    var name: String
    var category: String                    // "People", "Government", "Business"
    var registrations: [String]
    var socials: [String: String]?           // twitter, instagram, etc.

    enum CodingKeys: String, CodingKey {
        case name, category, registrations, socials
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(String.self, forKey: .category)
        registrations = try container.decodeIfPresent([String].self, forKey: .registrations) ?? []
        socials = try container.decodeIfPresent([String: String].self, forKey: .socials)
        id = "\(name)-\(category)"
    }

    init(id: String = UUID().uuidString, name: String, category: String, registrations: [String] = [], socials: [String: String]? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.registrations = registrations
        self.socials = socials
    }
}

// MARK: - API Response Models
struct LiveDataResponse: Codable {
    let flights: [FlightData]?
    let military: [MilitaryData]?
    let timestamp: Int?
}

struct FlightData: Codable {
    let icao24: String?
    let callsign: String?
    let lat: Double?
    let lon: Double?
    let alt: Double?
    let spd: Double?
    let hdg: Double?
    let vr: Double?
    let sqk: String?
    let from: String?
    let to: String?
    let reg: String?
    let type: String?
    let op: String?
    let flag: String?
    let country: String?
}

struct MilitaryData: Codable {
    let icao24: String?
    let callsign: String?
    let lat: Double?
    let lon: Double?
    let alt: Double?
    let spd: Double?
    let hdg: Double?
    let type: String?
    let model: String?
    let force: String?
    let isUAV: Bool?
    let uavType: String?
    let wikiURL: String?
}

// MARK: - Connection State
enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case error(String)
}

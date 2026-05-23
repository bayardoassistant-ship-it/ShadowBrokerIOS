import SwiftUI
import MapKit

struct AircraftMapView: View {
    @ObservedObject var viewModel: AircraftViewModel
    @State private var selectedAnnotation: Aircraft?

    var body: some View {
        Map(coordinateRegion: $viewModel.region,
            annotationItems: viewModel.filteredAircraft) { aircraft in
            MapAnnotation(coordinate: aircraft.coordinate) {
                AircraftAnnotationView(aircraft: aircraft) {
                    viewModel.focusOnAircraft(aircraft)
                }
            }
        }
        .mapStyle(.hybrid(elevation: .realistic))
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 8) {
                connectionStatus
                lastUpdateBadge
            }
            .padding(.trailing, 12)
            .padding(.top, 60)
        }
        .overlay(alignment: .bottom) {
            if let selected = viewModel.selectedAircraft {
                AircraftDetailCard(aircraft: selected) {
                    viewModel.selectedAircraft = nil
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
    }

    private var connectionStatus: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var lastUpdateBadge: some View {
        Group {
            if let date = viewModel.lastUpdate {
                Text("Updated \(date, style: .relative)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    private var statusColor: Color {
        switch viewModel.connectionState {
        case .connected: return .green
        case .connecting: return .yellow
        case .error: return .red
        default: return .gray
        }
    }

    private var statusText: String {
        switch viewModel.connectionState {
        case .connected: return "LIVE"
        case .connecting: return "SYNC"
        case .error(let msg): return "ERR"
        default: return "OFFLINE"
        }
    }
}

// MARK: - Aircraft Pin (SkyTrack Explorer Glass-Cockpit Style)
struct AircraftAnnotationView: View {
    let aircraft: Aircraft
    let onTap: () -> Void

    private var pinColor: Color {
        Color(hex: aircraft.category.color)
    }

    private var isHighValue: Bool {
        aircraft.isHighlighted || aircraft.category == .militaryISR || aircraft.category == .militaryFighter
    }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                // Outer glow (Sky Blue radar blip effect for high-value tracks)
                if isHighValue {
                    Circle()
                        .fill(pinColor.opacity(0.25))
                        .frame(width: 42, height: 42)
                        .blur(radius: 8)
                }

                // Main pin body - glassmorphic circle
                Circle()
                    .fill(Color(.systemGray6).opacity(0.85))
                    .frame(width: isHighValue ? 22 : 18, height: isHighValue ? 22 : 18)
                    .overlay(
                        Circle()
                            .stroke(pinColor, lineWidth: isHighValue ? 2.0 : 1.5)
                    )
                    .overlay(
                        // Inner subtle glow
                        Circle()
                            .stroke(pinColor.opacity(0.4), lineWidth: 0.8)
                            .blur(radius: 1)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                    .shadow(color: pinColor.opacity(0.3), radius: isHighValue ? 6 : 3)

                // Aircraft icon / symbol
                Image(systemName: aircraft.category.icon)
                    .font(.system(size: isHighValue ? 11 : 9, weight: .semibold))
                    .foregroundStyle(pinColor)
                    .rotationEffect(.degrees(aircraft.heading ?? 0))
            }
            .frame(width: 44, height: 44)

            // Label for high-value aircraft only
            if isHighValue {
                Text(aircraft.trackedName ?? aircraft.callsign ?? "")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(Color(.systemGray6).opacity(0.75))
                            .overlay(
                                Capsule()
                                    .stroke(pinColor.opacity(0.6), lineWidth: 0.5)
                            )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 2)
            }
        }
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Detail Card
struct AircraftDetailCard: View {
    let aircraft: Aircraft
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(aircraft.trackedName ?? aircraft.callsign ?? "UNKNOWN")
                        .font(.title3.weight(.bold))
                    Text(aircraft.aircraftType ?? aircraft.registration ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(spacing: 20) {
                StatView(title: "ALT", value: aircraft.altitude.map { "\($0 / 1000, specifier: "%.0f")k ft" } ?? "—")
                StatView(title: "SPD", value: aircraft.speed.map { "\($0, specifier: "%.0f") kt" } ?? "—")
                StatView(title: "HDG", value: aircraft.heading.map { "\(Int($0))°" } ?? "—")
                StatView(title: "VR", value: aircraft.verticalRate.map { "\($0 > 0 ? "+" : "")\($0 / 100, specifier: "%.0f")00 fpm" } ?? "—")
            }

            if let force = aircraft.militaryForce {
                Label(force, systemImage: "shield.lefthalf.filled")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            }

            if aircraft.isUAV, let uav = aircraft.uavType {
                Label(uav, systemImage: "antenna.radiowaves.left.and.right")
                    .font(.caption)
                    .foregroundStyle(.cyan)
            }

            if let wiki = aircraft.wikiURL {
                Link("Wikipedia", destination: URL(string: wiki)!)
                    .font(.caption)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
    }
}

struct StatView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
        }
    }
}

// Color hex helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

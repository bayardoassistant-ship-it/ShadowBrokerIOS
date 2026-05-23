import Foundation
import MapKit
import Combine
import SwiftUI

@MainActor
final class AircraftViewModel: ObservableObject {
    @Published var aircraft: [Aircraft] = []
    @Published var filteredAircraft: [Aircraft] = []
    @Published var selectedAircraft: Aircraft?
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.0, longitude: -98.0), // USA center
        span: MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 60)
    )
    @Published var activeFilters: Set<AircraftCategory> = Set(AircraftCategory.allCases)
    @Published var showOnlyTracked = false
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var connectionState: ConnectionState = .disconnected
    @Published var lastUpdate: Date?

    let apiService = ShadowBrokerAPIService.shared
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // High-priority categories always shown
    private let alwaysVisible: Set<AircraftCategory> = [.airForceOne, .presidential, .billionaire, .militaryISR]

    init() {
        setupBindings()
        startAutoRefresh()
    }

    deinit {
        Task { @MainActor [weak self] in
            self?.refreshTimer?.invalidate()
        }
    }

    private func setupBindings() {
        // React to filter/search changes
        Publishers.CombineLatest4($activeFilters, $showOnlyTracked, $searchText, $aircraft)
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] filters, onlyTracked, search, all in
                self?.applyFilters(filters: filters, onlyTracked: onlyTracked, search: search, allAircraft: all)
            }
            .store(in: &cancellables)
    }

    private func applyFilters(filters: Set<AircraftCategory>, onlyTracked: Bool, search: String, allAircraft: [Aircraft]) {
        var result = allAircraft

        if onlyTracked {
            result = result.filter { $0.isTracked || $0.isHighlighted }
        }

        result = result.filter { filters.contains($0.category) || alwaysVisible.contains($0.category) }

        if !search.isEmpty {
            let q = search.lowercased()
            result = result.filter {
                ($0.callsign?.lowercased().contains(q) ?? false) ||
                ($0.registration?.lowercased().contains(q) ?? false) ||
                ($0.trackedName?.lowercased().contains(q) ?? false) ||
                ($0.`operator`?.lowercased().contains(q) ?? false)
            }
        }

        // Sort: highlighted first, then by priority
        result.sort {
            if $0.isHighlighted != $1.isHighlighted { return $0.isHighlighted }
            return $0.category.priority < $1.category.priority
        }

        filteredAircraft = result
    }

    // MARK: - Data Refresh
    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            let newData = try await apiService.fetchLiveData()
            // Merge with existing to keep smooth updates
            aircraft = mergeAircraft(current: aircraft, new: newData)
            lastUpdate = apiService.lastUpdate
        } catch {
            errorMessage = "Failed to fetch aircraft: \(error.localizedDescription)"
            // Seed with demo data if everything fails
            if aircraft.isEmpty {
                aircraft = demoAircraft()
            }
        }

        isLoading = false
        applyFilters(filters: activeFilters, onlyTracked: showOnlyTracked, search: searchText, allAircraft: aircraft)
    }

    private func mergeAircraft(current: [Aircraft], new: [Aircraft]) -> [Aircraft] {
        var dict = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        for ac in new {
            dict[ac.id] = ac
        }
        return Array(dict.values)
    }

    func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
        Task { await refresh() } // initial load
    }

    // MARK: - Filtering UI Helpers
    func toggleFilter(_ category: AircraftCategory) {
        if activeFilters.contains(category) {
            activeFilters.remove(category)
        } else {
            activeFilters.insert(category)
        }
    }

    func resetFilters() {
        activeFilters = Set(AircraftCategory.allCases)
        showOnlyTracked = false
        searchText = ""
    }

    func focusOnAircraft(_ ac: Aircraft) {
        selectedAircraft = ac
        withAnimation(.easeInOut(duration: 0.6)) {
            region = MKCoordinateRegion(
                center: ac.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 2.5, longitudeDelta: 2.5)
            )
        }
    }

    // MARK: - Demo Data (fallback when offline)
    private func demoAircraft() -> [Aircraft] {
        let sampleAircraft: [Aircraft] = [
            Aircraft(id: "AE0001", callsign: "AF1", registration: "92-9000", `operator`: "United States Air Force", aircraftType: "VC-25A", category: .airForceOne, tags: ["Presidential"], latitude: 38.95, longitude: -77.45, altitude: 39000, speed: 520, heading: 245, verticalRate: 0, squawk: "1111", origin: "Andrews", destination: "LAX", isTracked: true, trackedName: "Air Force One", trackedCategory: "Government", country: "United States", flag: "🇺🇸", militaryForce: "USAF", isUAV: false, uavType: nil, wikiURL: nil, emissions: nil, isGPSJammed: false, lastUpdated: Date()),
            Aircraft(id: "A00002", callsign: "SAM46", registration: "98-0002", `operator`: "United States Air Force", aircraftType: "C-32A", category: .presidential, tags: ["VP"], latitude: 39.1, longitude: -77.3, altitude: 41000, speed: 480, heading: 180, verticalRate: -200, squawk: "2222", origin: "Andrews", destination: nil, isTracked: true, trackedName: "Air Force Two", trackedCategory: "Government", country: "United States", flag: "🇺🇸", militaryForce: "USAF", isUAV: false, uavType: nil, wikiURL: nil, emissions: nil, isGPSJammed: false, lastUpdated: Date()),
            Aircraft(id: "N628TS", callsign: "TSLA1", registration: "N628TS", `operator`: "SpaceX", aircraftType: "G650", category: .billionaire, tags: ["Elon Musk"], latitude: 37.4, longitude: -122.0, altitude: 45000, speed: 490, heading: 310, verticalRate: 1200, squawk: "4444", origin: "SJC", destination: "AUS", isTracked: true, trackedName: "Elon Musk", trackedCategory: "People", country: "United States", flag: "🇺🇸", militaryForce: nil, isUAV: false, uavType: nil, wikiURL: nil, emissions: nil, isGPSJammed: false, lastUpdated: Date()),
            Aircraft(id: "RCH123", callsign: "RCH123", registration: nil, `operator`: "USAF", aircraftType: "KC-135R", category: .militaryTanker, tags: ["Tanker"], latitude: 35.5, longitude: -95.2, altitude: 28000, speed: 420, heading: 90, verticalRate: 0, squawk: "7777", origin: nil, destination: nil, isTracked: true, trackedName: nil, trackedCategory: "Military", country: "United States", flag: "🇺🇸", militaryForce: "USAF", isUAV: false, uavType: nil, wikiURL: nil, emissions: nil, isGPSJammed: false, lastUpdated: Date()),
            Aircraft(id: "FORTE10", callsign: "FORTE10", registration: "05-2026", `operator`: "USAF", aircraftType: "RQ-4B", category: .militaryISR, tags: ["Global Hawk"], latitude: 42.1, longitude: -115.8, altitude: 55000, speed: 340, heading: 135, verticalRate: 0, squawk: nil, origin: nil, destination: nil, isTracked: true, trackedName: "RQ-4 Global Hawk", trackedCategory: "UAV", country: "United States", flag: "🇺🇸", militaryForce: "USAF", isUAV: true, uavType: "HALE Surveillance", wikiURL: "https://en.wikipedia.org/wiki/Northrop_Grumman_RQ-4_Global_Hawk", emissions: nil, isGPSJammed: false, lastUpdated: Date()),
        ]
        return sampleAircraft
    }
}

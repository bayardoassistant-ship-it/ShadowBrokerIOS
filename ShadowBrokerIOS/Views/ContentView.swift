import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AircraftViewModel()
    @State private var showingFilters = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                AircraftMapView(viewModel: viewModel)

                // Top bar
                VStack {
                    header
                    filterChips
                    Spacer()
                }
                .padding(.top, 8)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                FilterSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsSheet(viewModel: viewModel)
            }
            .searchable(text: $viewModel.searchText, prompt: "Search callsign, reg, or name")
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SHADOWBROKER")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Real-time OSINT Aircraft Intel")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showingFilters.toggle()
            } label: {
                Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                    .labelStyle(.titleAndIcon)
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "Tracked", isActive: viewModel.showOnlyTracked) {
                    viewModel.showOnlyTracked.toggle()
                }
                ForEach(AircraftCategory.allCases.filter { $0.priority < 6 }) { cat in
                    FilterChip(
                        title: cat.rawValue,
                        color: Color(hex: cat.color),
                        isActive: viewModel.activeFilters.contains(cat)
                    ) {
                        viewModel.toggleFilter(cat)
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 44)
    }
}

struct FilterChip: View {
    let title: String
    var color: Color = .white
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? color : Color.gray.opacity(0.3))
                .foregroundStyle(isActive ? .white : .secondary)
                .clipShape(Capsule())
        }
    }
}

struct FilterSheet: View {
    @ObservedObject var viewModel: AircraftViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Priority Layers") {
                    ForEach(AircraftCategory.allCases.sorted { $0.priority < $1.priority }) { category in
                        Toggle(isOn: Binding(
                            get: { viewModel.activeFilters.contains(category) },
                            set: { isOn in
                                if isOn {
                                    viewModel.activeFilters.insert(category)
                                } else {
                                    viewModel.activeFilters.remove(category)
                                }
                            }
                        )) {
                            Label(category.rawValue, systemImage: category.icon)
                                .foregroundStyle(Color(hex: category.color))
                        }
                    }
                }

                Section {
                    Toggle("Show Only Tracked / High-Value", isOn: $viewModel.showOnlyTracked)
                    Button("Reset All Filters") {
                        viewModel.resetFilters()
                        dismiss()
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct SettingsSheet: View {
    @ObservedObject var viewModel: AircraftViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Backend") {
                    TextField("ShadowBroker URL", text: $viewModel.api.baseURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                    Text("Point this at your running ShadowBroker instance (docker compose up)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Data") {
                    Button("Force Refresh Now") {
                        Task { await viewModel.refresh() }
                        dismiss()
                    }
                    Button("Load Tracked Names DB") {
                        // Would merge with plane_alert + tracked_names.json
                    }
                }

                Section("About") {
                    Text("ShadowBroker iOS — Mobile client for the open-source geospatial intelligence platform.")
                        .font(.footnote)
                    Link("GitHub Repo", destination: URL(string: "https://github.com/BigBodyCobain/Shadowbroker")!)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

import SwiftUI

/// Founder-only curation console. Presented from a long-press on the Profile
/// wordmark, gated on `Config.founderEmail`. Internal tooling — strings are
/// English on purpose. Source labels are shown; source URLs never are.
struct AdminView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AdminViewModel()
    @State private var tab: AdminTab = .addPlace

    enum AdminTab: String, CaseIterable, Identifiable {
        case addPlace = "Add place"
        case featured = "Featured"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pinCream.ignoresSafeArea()
                VStack(spacing: 12) {
                    Picker("", selection: $tab) {
                        ForEach(AdminTab.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if let error = vm.errorMessage {
                        Text(error).font(.pinBody(12)).foregroundStyle(Color.pinClayDeep)
                            .padding(.horizontal)
                    }

                    Group {
                        switch tab {
                        case .addPlace:  AddPlaceView(vm: vm)
                        case .featured:  FeaturedListView(vm: vm)
                        }
                    }
                }
            }
            .navigationTitle("Admin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .task { await vm.load() }
        }
    }
}

// MARK: - Add place (MapKit)

private struct AddPlaceView: View {
    @ObservedObject var vm: AdminViewModel
    @State private var pending: Restaurant?
    @State private var cuisine = ""
    @State private var featured = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    TextField("Search Apple Maps…", text: $vm.addQuery)
                        .pinAdminField()
                        .onSubmit { Task { await vm.searchMap() } }
                    Button("Search") { Task { await vm.searchMap() } }
                        .buttonStyle(PinTextLinkStyle(size: 14))
                }
                ForEach(vm.mapResults) { r in
                    Button {
                        pending = r; cuisine = r.cuisine; featured = false
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.name).font(.pinBody(15, weight: .medium)).foregroundStyle(Color.pinInk)
                            Text(r.address).font(.pinBody(12)).foregroundStyle(Color.pinInkMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12).pinCard()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
        .sheet(item: $pending) { r in
            NavigationStack {
                Form {
                    Section("Venue") { Text(r.name); Text(r.address).foregroundStyle(.secondary) }
                    Section("Cuisine") { TextField("Cuisine", text: $cuisine) }
                    Section { Toggle("Featured", isOn: $featured) }
                }
                .navigationTitle("Add restaurant")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Cancel") { pending = nil } }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Add") {
                            Task { await vm.addRestaurant(r, cuisine: cuisine, isFeatured: featured); pending = nil }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Featured toggles

private struct FeaturedListView: View {
    @ObservedObject var vm: AdminViewModel
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(vm.restaurants) { r in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.name).font(.pinBody(15)).foregroundStyle(Color.pinInk)
                            Text(r.cuisine).font(.pinBody(12)).foregroundStyle(Color.pinInkMuted)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { r.isFeatured },
                            set: { newVal in Task { await vm.setFeatured(r, newVal) } }
                        ))
                        .labelsHidden().tint(Color.pinClay)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.pinShell.opacity(0.5)))
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
    }
}

private extension View {
    func pinAdminField() -> some View {
        self.font(.pinBody(14))
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.pinCream))
    }
}

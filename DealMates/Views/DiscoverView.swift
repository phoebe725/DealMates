import SwiftUI
import CoreLocation

enum RestaurantSortMode: String, CaseIterable, Identifiable {
    case name = "Name (A–Z)"
    case distance = "Distance: Nearest"
    var id: String { rawValue }
}

struct DiscoverView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var vm = RestaurantViewModel()
    @ObservedObject private var locationManager = LocationManager.shared
    @State private var selectedRestaurant: Restaurant?
    @State private var sortMode: RestaurantSortMode = .name

    @State private var showMap = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.restaurants.isEmpty {
                    loadingState
                } else if visibleRestaurants.isEmpty {
                    emptyState
                } else {
                    restaurantList
                }
            }
            .navigationTitle("DealMates")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        cuisineFilterMenu
                        Button { showMap = true } label: { Image(systemName: "map") }
                        userBadge
                    }
                }
            }
            .searchable(
                text: $vm.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search restaurants or cuisine"
            )
            .navigationDestination(item: $selectedRestaurant) { restaurant in
                RestaurantBoardView(restaurant: restaurant)
                    .onDisappear {
                        Task { await vm.refreshActivePlanCount(for: restaurant.id) }
                    }
            }
        }
        .task {
            await vm.load()
            locationManager.requestPermissionAndStart()
        }
        .sheet(isPresented: $showMap) {
            RestaurantMapView()
                .environmentObject(vm)
                .environmentObject(authViewModel)
        }
    }

    // MARK: - Computed

    private var visibleRestaurants: [Restaurant] {
        let base = vm.filteredRestaurants
        switch sortMode {
        case .name:
            return base
        case .distance:
            guard let userLoc = locationManager.currentLocation else { return base }
            return base.sorted { a, b in
                distance(from: userLoc, to: a) < distance(from: userLoc, to: b)
            }
        }
    }

    private func distance(from user: CLLocation, to r: Restaurant) -> CLLocationDistance {
        guard let lat = r.latitude, let lon = r.longitude else { return .infinity }
        return user.distance(from: CLLocation(latitude: lat, longitude: lon))
    }

    // MARK: - Sub-views

    private var restaurantList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(visibleRestaurants) { restaurant in
                    Button {
                        selectedRestaurant = restaurant
                    } label: {
                        RestaurantCardView(restaurant: restaurant)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .refreshable { await vm.load() }
        .animation(nil, value: visibleRestaurants.map(\.id))
        .transaction { $0.animation = nil }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Finding restaurants nearby…")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text(vm.searchText.isEmpty ? "No restaurants yet" : "No results for \"\(vm.searchText)\"")
                .font(.headline)
            if !vm.searchText.isEmpty {
                Text("Try a different name or cuisine.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var userBadge: some View {
        Label(authViewModel.displayName, systemImage: "person.circle")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    private var cuisineFilterMenu: some View {
        cuisineFilterMenuRaw
            .transaction { $0.animation = nil }
    }

    private var cuisineFilterMenuRaw: some View {
        Menu {
            Section("Cuisine") {
                Button {
                    vm.cuisineFilter = nil
                } label: {
                    Label("All cuisines", systemImage: vm.cuisineFilter == nil ? "checkmark" : "")
                }
                ForEach(vm.availableCuisines, id: \.self) { cuisine in
                    Button {
                        vm.cuisineFilter = cuisine
                    } label: {
                        Label(AppLocale.localizedCuisine(cuisine), systemImage: vm.cuisineFilter == cuisine ? "checkmark" : "")
                    }
                }
            }
            Section("Sort") {
                ForEach(RestaurantSortMode.allCases) { mode in
                    Button {
                        sortMode = mode
                    } label: {
                        Label(mode.rawValue, systemImage: sortMode == mode ? "checkmark" : "")
                    }
                }
            }
        } label: {
            Image(systemName: (vm.cuisineFilter != nil || sortMode != .name) ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }
}

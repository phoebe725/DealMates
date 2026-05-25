import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var vm = RestaurantViewModel()
    @State private var selectedRestaurant: Restaurant?

    @State private var showMap = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.restaurants.isEmpty {
                    loadingState
                } else if vm.filteredRestaurants.isEmpty {
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
            .refreshable { await vm.load() }
            .navigationDestination(item: $selectedRestaurant) { restaurant in
                RestaurantBoardView(restaurant: restaurant)
                    .onDisappear {
                        Task { await vm.refreshActivePlanCount(for: restaurant.id) }
                    }
            }
        }
        .task { await vm.load() }
        .sheet(isPresented: $showMap) {
            RestaurantMapView()
                .environmentObject(vm)
                .environmentObject(authViewModel)
        }
    }

    // MARK: - Sub-views

    private var restaurantList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(vm.filteredRestaurants) { restaurant in
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
}

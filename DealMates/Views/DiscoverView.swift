import SwiftUI
import CoreLocation

enum RestaurantSortMode: String, CaseIterable, Identifiable {
    case name = "Name (A–Z)"
    case distance = "Distance: Nearest"
    var id: String { rawValue }
}

enum DiscoverMode: String, CaseIterable, Identifiable {
    case restaurants = "Restaurants"
    case plans = "Plans"
    var id: String { rawValue }
}

struct DiscoverView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var vm = RestaurantViewModel()
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var subs = SubscriptionsViewModel.shared
    @ObservedObject private var userCache = UserCache.shared
    @ObservedObject private var restaurantCache = RestaurantCache.shared
    @State private var selectedRestaurant: Restaurant?
    @State private var selectedPlan: Plan?
    @State private var sortMode: RestaurantSortMode = .name
    @State private var mode: DiscoverMode = .restaurants
    @State private var subscribedOnly: Bool = false
    @State private var allPlans: [Plan] = []
    @State private var plansLoading: Bool = false

    @State private var showMap = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $mode) {
                    ForEach(DiscoverMode.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Group {
                    switch mode {
                    case .restaurants:
                        if vm.isLoading && vm.restaurants.isEmpty { loadingState }
                        else if visibleRestaurants.isEmpty { emptyState }
                        else { restaurantList }
                    case .plans:
                        if plansLoading && allPlans.isEmpty { loadingState }
                        else { plansScroll }
                    }
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
            .navigationDestination(item: $selectedPlan) { plan in
                PlanDetailView(plan: plan, planVM: PlanViewModel(restaurantId: plan.restaurantId))
            }
        }
        .task {
            await vm.load()
            locationManager.requestPermissionAndStart()
            await loadAllPlans()
            await subs.load(currentUid: authViewModel.uid)
        }
        .sheet(isPresented: $showMap) {
            RestaurantMapView()
                .environmentObject(vm)
                .environmentObject(authViewModel)
        }
    }

    private var visiblePlans: [Plan] {
        let active = allPlans.filter { $0.needsMorePeople > 0 && $0.attendanceConfirmedAt == nil }
        return subscribedOnly
            ? active.filter { subs.subscribedRestaurantIds.contains($0.restaurantId) }
            : active
    }

    // Single always-mounted ScrollView so the .refreshable anchor never disappears
    // when the result set goes empty mid-refresh.
    private var plansScroll: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                Toggle("Subscribed restaurants only", isOn: $subscribedOnly)
                    .toggleStyle(.switch)
                    .padding(.horizontal, 4)

                if visiblePlans.isEmpty {
                    plansEmptyContent
                        .padding(.top, 40)
                } else {
                    ForEach(visiblePlans) { plan in
                        Button { selectedPlan = plan } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Text(restaurantCache.displayName(for: plan.restaurantId, fallback: plan.restaurantName))
                                        .font(.headline)
                                    Spacer()
                                    Label(plan.timeDisplay, systemImage: "clock")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Text("\(userCache.name(for: plan.creatorId, fallback: plan.creatorName)) · \(plan.currentPeople)/\(plan.neededPeople)")
                                    .font(.caption).foregroundColor(.secondary)
                                if plan.needsMorePeople > 0 {
                                    Text("Need \(plan.needsMorePeople) more")
                                        .font(.caption.bold()).foregroundColor(.orange)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .refreshable {
            await subs.load(currentUid: authViewModel.uid)
            await loadAllPlans()
        }
    }

    private var plansEmptyContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 56)).foregroundColor(.secondary)
            if subscribedOnly && subs.subscribedRestaurantIds.isEmpty {
                Text("You haven't subscribed to any restaurants yet")
                    .font(.headline).multilineTextAlignment(.center)
                Text("Open a restaurant and tap the bell icon to subscribe.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
            } else {
                Text(subscribedOnly ? "No active plans at your subscribed restaurants" : "No active plans right now")
                    .font(.headline).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func loadAllPlans() async {
        // Only show the full-screen spinner on first load; otherwise keep the list visible
        // so the pull-to-refresh control stays attached.
        if allPlans.isEmpty { plansLoading = true }
        do {
            allPlans = try await DatabaseService.shared.fetchAllActivePlans()
            await userCache.prefetch(ids: allPlans.map(\.creatorId))
        } catch {
            print("[DEBUG] loadAllPlans failed: \(error)")
        }
        plansLoading = false
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
                    if vm.cuisineFilter == nil { Label("All cuisines", systemImage: "checkmark") }
                    else { Text("All cuisines") }
                }
                ForEach(vm.availableCuisines, id: \.self) { cuisine in
                    Button {
                        vm.cuisineFilter = cuisine
                    } label: {
                        if vm.cuisineFilter == cuisine { Label(AppLocale.localizedCuisine(cuisine), systemImage: "checkmark") }
                        else { Text(AppLocale.localizedCuisine(cuisine)) }
                    }
                }
            }
            Section("Sort") {
                ForEach(RestaurantSortMode.allCases) { mode in
                    Button {
                        sortMode = mode
                    } label: {
                        if sortMode == mode { Label(LocalizedStringKey(mode.rawValue), systemImage: "checkmark") }
                        else { Text(LocalizedStringKey(mode.rawValue)) }
                    }
                }
            }
        } label: {
            Image(systemName: (vm.cuisineFilter != nil || sortMode != .name) ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }
}

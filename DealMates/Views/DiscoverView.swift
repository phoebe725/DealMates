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
    @State private var didInitialLoad = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pinCream.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                    Group {
                        switch mode {
                        case .restaurants:
                            if vm.isLoading && vm.restaurants.isEmpty { loadingState }
                            else if visibleRestaurants.isEmpty { emptyRestaurants }
                            else { restaurantList }
                        case .plans:
                            if plansLoading && allPlans.isEmpty { loadingState }
                            else { plansScroll }
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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
        .onAppear {
            // `.onAppear` fires every time this tab becomes the visible one —
            // unlike `.task`, which only fires on first creation. Re-fetching
            // restaurants + active pins on each landing keeps the Discover
            // tab fresh without requiring a manual pull.
            if !didInitialLoad {
                didInitialLoad = true
                locationManager.requestPermissionAndStart()
            }
            Task {
                await vm.load()
                await loadAllPlans()
                await subs.load(currentUid: authViewModel.uid)
            }
        }
        .sheet(isPresented: $showMap) {
            RestaurantMapView()
                .environmentObject(vm)
                .environmentObject(authViewModel)
        }
    }

    // MARK: - Header (greeting + segmented mode + filters + search)

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title row with wordmark + map + filter
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    (
                        Text("Find your ")
                            .font(.pinHero(28, weight: .light))
                            .foregroundStyle(Color.pinInk)
                        +
                        Text("raft.")
                            .font(.pinAccent(38))
                            .foregroundStyle(Color.pinClayDeep)
                    )
                    .lineLimit(1)
                    Text("Restaurants and pins near you.")
                        .font(.pinSubtitle(13))
                        .foregroundStyle(Color.pinInkMuted)
                }
                Spacer()
                headerActions
            }

            PinSegmentedPicker(
                options: [(value: DiscoverMode.restaurants, label: "Restaurants"),
                          (value: DiscoverMode.plans, label: "Pins")],
                selection: $mode
            )

            if mode == .restaurants {
                PinSearchField(text: $vm.searchText, placeholder: "Search restaurants or cuisine")
            }
        }
    }

    @ViewBuilder
    private var headerActions: some View {
        HStack(spacing: 8) {
            Button { showMap = true } label: {
                Image(systemName: "map")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.pinInk)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.pinShell))
            }
            .buttonStyle(.plain)

            cuisineFilterMenu
        }
    }

    private var cuisineFilterMenu: some View {
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
            Image(systemName: (vm.cuisineFilter != nil || sortMode != .name)
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.pinClay)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.pinShell))
        }
    }

    // MARK: - Restaurants list

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
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .padding(.bottom, 24)
        }
        .refreshable {
            await vm.load()
            await UnreadManager.shared.refresh(currentUid: authViewModel.uid)
        }
        .animation(nil, value: visibleRestaurants.map(\.id))
    }

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

    // MARK: - Plans (pins) tab

    private var visiblePlans: [Plan] {
        let active = allPlans.filter { $0.needsMorePeople > 0 && $0.attendanceConfirmedAt == nil }
        let filtered = subscribedOnly
            ? active.filter { subs.subscribedRestaurantIds.contains($0.restaurantId) }
            : active
        // Soonest meet-up at the top.
        return filtered.sorted { $0.scheduledAt < $1.scheduledAt }
    }

    private var plansScroll: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                subscribedToggle

                if visiblePlans.isEmpty {
                    plansEmptyContent
                        .padding(.top, 40)
                } else {
                    ForEach(visiblePlans) { plan in
                        Button { selectedPlan = plan } label: {
                            planRow(plan)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .padding(.bottom, 24)
        }
        .refreshable {
            await subs.load(currentUid: authViewModel.uid)
            await loadAllPlans()
            await UnreadManager.shared.refresh(currentUid: authViewModel.uid)
        }
    }

    private var subscribedToggle: some View {
        HStack {
            Text("Only restaurants I'm watching")
                .font(.pinBody(14))
                .foregroundStyle(Color.pinInk)
            Spacer()
            Toggle("", isOn: $subscribedOnly)
                .labelsHidden()
                .tint(Color.pinClay)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.pinShell)
        )
    }

    private func planRow(_ plan: Plan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(restaurantCache.displayName(for: plan.restaurantId, fallback: plan.restaurantName))
                    .font(.pinBody(15, weight: .medium))
                    .foregroundStyle(Color.pinInk)
                Spacer()
                Label(plan.timeDisplay, systemImage: "clock")
                    .font(.pinSubtitle(12))
                    .foregroundStyle(Color.pinInkMuted)
            }
            HStack(spacing: 8) {
                LiveAvatar(
                    userId: plan.creatorId,
                    size: 22,
                    fontSize: 10,
                    fallbackName: plan.creatorName,
                    fallbackAvatarURL: plan.creatorAvatarURL
                )
                Text(userCache.name(for: plan.creatorId, fallback: plan.creatorName))
                    .font(.pinSubtitle(13))
                    .foregroundStyle(Color.pinInkMuted)
                Spacer()
                if plan.needsMorePeople > 0 {
                    PinChip(text: "Needs \(plan.needsMorePeople)", systemImage: "person.3.fill", tint: .pinClay)
                } else {
                    PinChip(text: "Full", systemImage: "checkmark.seal.fill", tint: .pinSageDeep)
                }
            }
        }
        .padding(14)
        .pinCard()
    }

    private var plansEmptyContent: some View {
        if subscribedOnly && subs.subscribedRestaurantIds.isEmpty {
            return AnyView(PinEmptyState(
                title: "Pick your spots first",
                message: "Open a restaurant and tap the bell to watch it. New pins there land in this tab.",
                systemImage: "bell"
            ))
        } else {
            return AnyView(PinEmptyState(
                title: subscribedOnly ? "Nothing pinned here yet" : "No live pins right now",
                message: subscribedOnly
                    ? "Try unticking the toggle to see all active pins."
                    : "Be the first — pin a plan at a restaurant.",
                systemImage: "mappin"
            ))
        }
    }

    private func loadAllPlans() async {
        if allPlans.isEmpty { plansLoading = true }
        do {
            allPlans = try await DatabaseService.shared.fetchAllActivePlans()
            await userCache.prefetch(ids: allPlans.map(\.creatorId))
        } catch {
            print("[DEBUG] loadAllPlans failed: \(error)")
        }
        plansLoading = false
    }

    // MARK: - Loading / empty states

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView().tint(Color.pinInkMuted)
            Text("Finding restaurants nearby…")
                .font(.pinSubtitle(14))
                .foregroundStyle(Color.pinInkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyRestaurants: some View {
        let searchEmpty = !vm.searchText.isEmpty
        return PinEmptyState(
            title: searchEmpty ? "No matches for \"\(vm.searchText)\"" : "No restaurants yet",
            message: searchEmpty
                ? "Try a different name or cuisine."
                : "The list is empty — pull to refresh.",
            systemImage: "magnifyingglass"
        )
    }
}

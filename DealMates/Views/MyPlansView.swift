import SwiftUI
import CoreLocation

// MARK: - MyPlansView

struct MyPlansView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var userCache = UserCache.shared
    @ObservedObject private var restaurantCache = RestaurantCache.shared
    @State private var plans: [Plan] = []
    @State private var restaurantById: [String: Restaurant] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var cuisineFilter: String? = nil
    @State private var statusFilter: PlanStatusFilter = .all
    @State private var sortMode: PlanSortMode = .timeAsc
    @State private var profileTarget: UserProfileSheetTarget?
    @State private var bucket: MyPlansBucket = .active

    enum MyPlansBucket: String, CaseIterable, Identifiable {
        case active = "Active"
        case completed = "Completed"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Bucket", selection: $bucket) {
                    ForEach(MyPlansBucket.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Group {
                    if isLoading {
                        ProgressView("Loading your plans…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if visiblePlans.isEmpty {
                        emptyState
                    } else {
                        planList
                    }
                }
            }
            .navigationTitle("My Plans")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    filterSortMenu
                }
            }
            .onAppear { Task { await load() } }
            .refreshable { await load() }
            .sheet(item: $profileTarget) { target in
                UserProfileView(userId: target.id)
            }
        }
    }

    // MARK: - Filter / sort

    private var availableCuisines: [String] {
        Array(Set(restaurantById.values.map(\.cuisine))).sorted()
    }

    private var visiblePlans: [Plan] {
        var result = plans
        // Active = still needs people AND attendance not yet confirmed.
        // Completed = group is full OR attendance has been confirmed.
        switch bucket {
        case .active:
            result = result.filter { $0.needsMorePeople > 0 && $0.attendanceConfirmedAt == nil }
        case .completed:
            result = result.filter { $0.needsMorePeople == 0 || $0.attendanceConfirmedAt != nil }
        }
        if let cuisine = cuisineFilter, !cuisine.isEmpty {
            result = result.filter { restaurantById[$0.restaurantId]?.cuisine == cuisine }
        }
        if statusFilter != .all {
            result = result.filter { statusFilter.matches($0) }
        }
        switch sortMode {
        case .timeAsc:  result.sort { $0.scheduledAt < $1.scheduledAt }
        case .timeDesc: result.sort { $0.scheduledAt > $1.scheduledAt }
        case .distance:
            guard let userLoc = locationManager.currentLocation else { break }
            result.sort { distance(to: $0, from: userLoc) < distance(to: $1, from: userLoc) }
        }
        return result
    }

    private func distance(to plan: Plan, from user: CLLocation) -> CLLocationDistance {
        guard let r = restaurantById[plan.restaurantId],
              let lat = r.latitude, let lon = r.longitude else { return .infinity }
        return user.distance(from: CLLocation(latitude: lat, longitude: lon))
    }

    private var filterSortMenu: some View {
        filterSortMenuRaw
            .transaction { $0.animation = nil }
    }

    private var filterSortMenuRaw: some View {
        Menu {
            Section("Cuisine") {
                Button {
                    cuisineFilter = nil
                } label: {
                    if cuisineFilter == nil { Label("All cuisines", systemImage: "checkmark") }
                    else { Text("All cuisines") }
                }
                ForEach(availableCuisines, id: \.self) { cuisine in
                    Button {
                        cuisineFilter = cuisine
                    } label: {
                        if cuisineFilter == cuisine { Label(AppLocale.localizedCuisine(cuisine), systemImage: "checkmark") }
                        else { Text(AppLocale.localizedCuisine(cuisine)) }
                    }
                }
            }
            Section("Status") {
                ForEach(PlanStatusFilter.allCases) { s in
                    Button {
                        statusFilter = s
                    } label: {
                        if statusFilter == s { Label(LocalizedStringKey(s.rawValue), systemImage: "checkmark") }
                        else { Text(LocalizedStringKey(s.rawValue)) }
                    }
                }
            }
            Section("Sort") {
                ForEach(PlanSortMode.allCases) { mode in
                    Button {
                        sortMode = mode
                    } label: {
                        if sortMode == mode { Label(LocalizedStringKey(mode.rawValue), systemImage: "checkmark") }
                        else { Text(LocalizedStringKey(mode.rawValue)) }
                    }
                }
            }
        } label: {
            Image(systemName: (cuisineFilter != nil || statusFilter != .all || sortMode != .timeAsc) ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }

    // MARK: - Sub-views

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text(plans.isEmpty ? "No active plans yet" : "No plans match your filter")
                .font(.headline)
            Text(plans.isEmpty ? "Join or create a plan from the Discover tab." : "Try clearing your filter.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var planList: some View {
        List(visiblePlans) { plan in
            NavigationLink(destination: PlanDetailView(plan: plan, planVM: PlanViewModel(restaurantId: plan.restaurantId))) {
                planRow(plan)
            }
        }
        .listStyle(.insetGrouped)
        .animation(nil, value: visiblePlans.map(\.id))
    }

    private func planRow(_ plan: Plan) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(restaurantCache.displayName(for: plan.restaurantId, fallback: plan.restaurantName))
                .font(.headline)

            HStack(spacing: 8) {
                Button {
                    profileTarget = UserProfileSheetTarget(id: plan.creatorId)
                } label: {
                    HStack(spacing: 8) {
                        LiveAvatar(
                            userId: plan.creatorId,
                            size: 22,
                            fontSize: 11,
                            fallbackName: plan.creatorName,
                            fallbackAvatarURL: plan.creatorAvatarURL
                        )
                        Text(userCache.name(for: plan.creatorId, fallback: plan.creatorName))
                            .font(.subheadline)
                    }
                }
                .buttonStyle(.plain)
                Text(plan.creatorId == authViewModel.uid ? "You (Organiser)" : "Organiser")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .clipShape(Capsule())
            }

            Label(plan.timeDisplay, systemImage: "clock")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if plan.needsMorePeople > 0 {
                Text("Needs \(plan.needsMorePeople) more")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .bold()
            } else {
                Text("Ready to go!")
                    .font(.caption)
                    .foregroundColor(.green)
                    .bold()
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Load

    private func load() async {
        guard authViewModel.isSignedIn else { return }
        // Only flip the full-screen spinner on for the first load, not for pull-to-refresh.
        let isFirstLoad = plans.isEmpty
        if isFirstLoad { isLoading = true }
        locationManager.requestPermissionAndStart()
        async let plansTask = DatabaseService.shared.fetchMyPlans(userId: authViewModel.uid)
        async let restaurantsTask = DatabaseService.shared.fetchRestaurants()
        // Only overwrite on success — a failed refresh should leave the existing list intact
        // rather than blanking it out (and stranding the refresh spinner on the empty view).
        if let fetched = try? await plansTask { plans = fetched }
        if let restaurants = try? await restaurantsTask {
            restaurantById = Dictionary(uniqueKeysWithValues: restaurants.map { ($0.id, $0) })
        }
        // Prefetch organiser profiles so the live name/avatar fill in straight away rather than
        // briefly showing the stale `plan.creatorName` snapshot from the row.
        await userCache.prefetch(ids: plans.map(\.creatorId))
        isLoading = false
    }
}

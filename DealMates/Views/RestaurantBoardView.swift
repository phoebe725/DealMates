import SwiftUI

struct DMTarget: Identifiable, Hashable {
    let uid: String
    var id: String { uid }
}

enum PlanTimeFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case asap = "ASAP"
    case scheduled = "Scheduled"
    var id: String { rawValue }
}

enum PlanSortMode: String, CaseIterable, Identifiable {
    case timeAsc = "Time: Earliest"
    case timeDesc = "Time: Latest"
    case nameAsc = "Name (A–Z)"
    case distance = "Distance: Nearest"
    var id: String { rawValue }
}

enum PlanStatusFilter: String, CaseIterable, Identifiable {
    case all = "All statuses"
    case ready = "Ready to go!"
    case need1 = "Need 1 more"
    case need2 = "Need 2 more"
    case need3plus = "Need 3+ more"
    var id: String { rawValue }

    func matches(_ plan: Plan) -> Bool {
        switch self {
        case .all:       return true
        case .ready:     return plan.needsMorePeople == 0
        case .need1:     return plan.needsMorePeople == 1
        case .need2:     return plan.needsMorePeople == 2
        case .need3plus: return plan.needsMorePeople >= 3
        }
    }
}

struct RestaurantBoardView: View {
    let restaurant: Restaurant
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var vm: PlanViewModel
    @State private var showCreatePlan = false
    @State private var selectedPlan: Plan?
    @State private var dmTarget: DMTarget?
    @State private var profileTarget: UserProfileSheetTarget?
    @State private var timeFilter: PlanTimeFilter = .all
    @State private var statusFilter: PlanStatusFilter = .all
    @State private var sortMode: PlanSortMode = .timeAsc
    @State private var offers: [RestaurantOffer] = []
    @ObservedObject private var subs = SubscriptionsViewModel.shared

    /// Offers-first; fall back to the legacy deals JSON when there are no rows.
    private var displayOffers: [RestaurantOffer] {
        offers.isEmpty
            ? restaurant.displayDeals.enumerated().map { RestaurantOffer.fromDeal($1, restaurantId: restaurant.id, index: $0) }
            : offers
    }

    init(restaurant: Restaurant) {
        self.restaurant = restaurant
        _vm = StateObject(wrappedValue: PlanViewModel(restaurantId: restaurant.id))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.pinCream.ignoresSafeArea()

            content
            createButton
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(restaurant.displayName)
                    .font(.pinBody(16, weight: .medium))
                    .foregroundStyle(Color.pinInk)
                    .lineLimit(1)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 6) {
                    subscribeButton
                    filterSortMenu
                }
            }
        }
        .toolbarBackground(Color.pinCream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showCreatePlan) {
            CreatePlanView(restaurant: restaurant, planVM: vm)
        }
        .sheet(item: $profileTarget) { target in
            UserProfileView(userId: target.id)
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedPlan != nil },
            set: { if !$0 { selectedPlan = nil } }
        )) {
            if let plan = selectedPlan {
                PlanDetailView(plan: plan, planVM: vm)
                    .id(plan.id)
            }
        }
        .navigationDestination(item: $dmTarget) { target in
            DMChatView(currentUid: authViewModel.uid, otherUid: target.uid)
        }
        .onAppear  { vm.startListening() }
        .task { offers = await DatabaseService.shared.fetchOffers(restaurantId: restaurant.id) }
        .onDisappear { vm.stopListening() }
        .alert("Heads up", isPresented: Binding(
            get:  { vm.errorMessage != nil },
            set:  { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { vm.errorMessage = nil }
        } message: { Text(vm.errorMessage ?? "") }
        .alert("Done", isPresented: Binding(
            get:  { vm.successMessage != nil },
            set:  { if !$0 { vm.successMessage = nil } }
        )) {
            Button("OK", role: .cancel) { vm.successMessage = nil }
        } message: { Text(vm.successMessage ?? "") }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.plans.isEmpty {
            VStack(spacing: 14) {
                ProgressView().tint(Color.pinInkMuted)
                Text("Loading pins at \(restaurant.displayName)…")
                    .font(.pinSubtitle(13))
                    .foregroundStyle(Color.pinInkMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.plans.isEmpty {
            ScrollView {
                VStack(spacing: 18) {
                    restaurantHeader
                    dealsBanner
                    emptyBoard
                        .padding(.top, 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 80)
            }
        } else {
            planList
        }
    }

    // MARK: - Restaurant header

    private var restaurantHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            (
                Text(restaurant.displayName)
                    .font(.pinHero(28, weight: .light))
                    .foregroundStyle(Color.pinInk)
            )
            .lineLimit(2)
            Text(restaurant.displayCuisine + " · " + restaurant.address)
                .font(.pinSubtitle(13))
                .foregroundStyle(Color.pinInkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Deals banner

    @ViewBuilder
    private var dealsBanner: some View {
        let shown = displayOffers
        if !shown.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.pinClay)
                    Text("Deals at this spot")
                        .font(.pinBody(12, weight: .medium))
                        .foregroundStyle(Color.pinClayDeep)
                }
                ForEach(shown) { offer in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(offer.displayTitle)
                                .font(.pinBody(14, weight: .medium))
                                .foregroundStyle(Color.pinInk)
                            if let badge = offer.groupBadge {
                                Text(badge)
                                    .font(.pinSubtitle(11).weight(.semibold))
                                    .foregroundStyle(Color.pinClayDeep)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.pinClay.opacity(0.18), in: Capsule())
                            }
                            if let pp = offer.pricePp {
                                Spacer()
                                Text("£\(pp, specifier: "%g")/pp")
                                    .font(.pinSubtitle(12).weight(.semibold))
                                    .foregroundStyle(Color.pinClayDeep)
                            }
                        }
                        if !offer.displayDescription.isEmpty {
                            Text(offer.displayDescription)
                                .font(.pinSubtitle(12))
                                .foregroundStyle(Color.pinInkMuted)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.pinClay.opacity(0.10))
            )
        }
    }

    // MARK: - Plan list

    private var planList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                restaurantHeader
                dealsBanner

                PinSectionHeader(title: "Active plans")
                    .padding(.top, 8)

                ForEach(visiblePlans, id: \.id) { plan in
                    PlanCardView(
                        plan: plan,
                        currentUID: authViewModel.uid,
                        onJoin:    { Task { await vm.join(plan: plan, userId: authViewModel.uid, userName: authViewModel.displayName) } },
                        onLeave:   { Task { await vm.leave(plan: plan, userId: authViewModel.uid, userName: authViewModel.displayName) } },
                        onOpen:    { selectedPlan = plan },
                        onMessage: { dmTarget = DMTarget(uid: plan.creatorId) },
                        onOrganiserTap: { uid in profileTarget = UserProfileSheetTarget(id: uid) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 96) // room for the floating CTA
        }
        .refreshable {
            await vm.refresh()
            await UnreadManager.shared.refresh(currentUid: authViewModel.uid)
        }
        .animation(nil, value: visiblePlans.map(\.id))
    }

    // MARK: - Filtering / sorting

    private var visiblePlans: [Plan] {
        var result = vm.plans
        switch timeFilter {
        case .all:       break
        case .asap:      result = result.filter { $0.isAsap }
        case .scheduled: result = result.filter { !$0.isAsap }
        }
        if statusFilter != .all {
            result = result.filter { statusFilter.matches($0) }
        }
        switch sortMode {
        case .timeAsc:  result.sort(by: Plan.defaultOrder)
        case .timeDesc: result.sort { $0.scheduledAt > $1.scheduledAt }
        case .nameAsc:
            // All plans share this restaurant, so A–Z sorts by organiser name.
            result.sort { $0.creatorName.localizedCaseInsensitiveCompare($1.creatorName) == .orderedAscending }
        case .distance: break
        }
        return result
    }

    private var filterSortMenu: some View {
        Menu {
            Section("When") {
                ForEach(PlanTimeFilter.allCases) { f in
                    Button {
                        timeFilter = f
                    } label: {
                        if timeFilter == f { Label(LocalizedStringKey(f.rawValue), systemImage: "checkmark") }
                        else { Text(LocalizedStringKey(f.rawValue)) }
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
                ForEach(PlanSortMode.allCases.filter { $0 != .distance }) { mode in
                    Button {
                        sortMode = mode
                    } label: {
                        if sortMode == mode { Label(LocalizedStringKey(mode.rawValue), systemImage: "checkmark") }
                        else { Text(LocalizedStringKey(mode.rawValue)) }
                    }
                }
            }
        } label: {
            Image(systemName: hasActiveFilter
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.pinClay)
        }
        .transaction { $0.animation = nil }
    }

    private var hasActiveFilter: Bool {
        timeFilter != .all || statusFilter != .all || sortMode != .timeAsc
    }

    private var subscribeButton: some View {
        let isSubscribed = subs.isSubscribed(restaurantId: restaurant.id)
        return Button {
            Task { await subs.toggle(restaurantId: restaurant.id, currentUid: authViewModel.uid) }
        } label: {
            Image(systemName: isSubscribed ? "bell.fill" : "bell")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isSubscribed ? Color.pinClay : Color.pinInk)
        }
    }

    // MARK: - Empty board

    private var emptyBoard: some View {
        PinEmptyState(
            title: "No active plans here yet",
            message: "Be the first to pin a plan.",
            systemImage: "mappin"
        )
    }

    // MARK: - Floating CTA

    private var createButton: some View {
        Button {
            showCreatePlan = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                Text("Pin a plan")
                    .font(.pinButton(14))
            }
            .foregroundStyle(Color.pinCream)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.pinClay)
            )
            .shadow(color: Color.pinClay.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.bottom, 24)
    }
}

import SwiftUI
import Combine

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
    @ObservedObject private var subs = SubscriptionsViewModel.shared

    init(restaurant: Restaurant) {
        self.restaurant = restaurant
        _vm = StateObject(wrappedValue: PlanViewModel(restaurantId: restaurant.id))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                if vm.isLoading && vm.plans.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.plans.isEmpty {
                    VStack(spacing: 0) {
                        dealsBanner
                        emptyBoard
                    }
                } else {
                    planList
                }
            }

            // Floating + button
            createButton
        }
        .navigationTitle(restaurant.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    subscribeButton
                    filterSortMenu
                }
            }
        }
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
            DMChatView(
                currentUid: authViewModel.uid,
                otherUid: target.uid
            )
        }
        .onAppear  { vm.startListening() }
        .onDisappear { vm.stopListening() }
        .alert("Error", isPresented: Binding(
            get:  { vm.errorMessage != nil },
            set:  { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .alert("Done", isPresented: Binding(
            get:  { vm.successMessage != nil },
            set:  { if !$0 { vm.successMessage = nil } }
        )) {
            Button("OK", role: .cancel) { vm.successMessage = nil }
        } message: {
            Text(vm.successMessage ?? "")
        }
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
        case .timeAsc:  result.sort { $0.scheduledAt < $1.scheduledAt }
        case .timeDesc: result.sort { $0.scheduledAt > $1.scheduledAt }
        case .distance: break
        }
        return result
    }

    private var filterSortMenu: some View {
        filterSortMenuRaw
            .transaction { $0.animation = nil }
    }

    private var filterSortMenuRaw: some View {
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
            Image(systemName: hasActiveFilter ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
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
                .foregroundColor(isSubscribed ? .orange : .primary)
        }
    }

    @ViewBuilder
    private var dealsBanner: some View {
        let deals = restaurant.displayDeals
        if !deals.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label("Deals", systemImage: "tag.fill")
                    .font(.caption.bold())
                    .foregroundColor(.orange)
                ForEach(Array(deals.enumerated()), id: \.offset) { _, deal in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(deal.title).font(.subheadline.bold())
                        Text(deal.detail).font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.1)))
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
    }

    // MARK: - Plan list

    private var planList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                dealsBanner
                ForEach(visiblePlans, id: \.id) { plan in
                    PlanCardView(
                        plan: plan,
                        currentUID: authViewModel.uid,
                        onJoin:    { Task { await vm.join(plan: plan, userId: authViewModel.uid, userName: authViewModel.displayName) } },
                        onLeave:   { Task { await vm.leave(plan: plan, userId: authViewModel.uid, userName: authViewModel.displayName) } },
                        onOpen:    { selectedPlan = plan },
                        onMessage: {
                            dmTarget = DMTarget(uid: plan.creatorId)
                        },
                        onOrganiserTap: { uid in
                            profileTarget = UserProfileSheetTarget(id: uid)
                        }
                    )
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 10)
            .padding(.bottom, 80) // room for FAB
        }
        .refreshable { await vm.refresh() }
        .animation(nil, value: visiblePlans.map(\.id))
    }

    // MARK: - Empty state

    private var emptyBoard: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.orange.opacity(0.6))
            Text("No active plans")
                .font(.headline)
            Text("Be the first to create a dining plan\nfor \(restaurant.displayName)!")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - FAB

    private var createButton: some View {
        Button {
            showCreatePlan = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.orange)
                .clipShape(Circle())
                .shadow(color: .orange.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, 24)
        .padding(.bottom, 28)
    }
}

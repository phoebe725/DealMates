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

    /// Active offers (restaurant_offers is the source of truth for promos).
    private var displayOffers: [RestaurantOffer] { offers }

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
                VStack(alignment: .leading, spacing: 18) {
                    dealsSection
                    VStack(spacing: 0) {
                        PinSectionHeader(title: "Active plans")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        emptyBoard.padding(.top, 16)
                    }
                    goodToKnowSection
                    infoSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 96)
            }
        } else {
            planList
        }
    }

    // MARK: - Current deals (top of page)

    @ViewBuilder
    private var dealsSection: some View {
        let deals = RestaurantOffer.deals(displayOffers)   // group_gated + deal
        if !deals.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                PinSectionHeader(title: "Current deals")
                ForEach(deals) { offer in
                    if offer.category == "group_gated" {
                        groupDealCard(offer)
                    } else {
                        dealCard(offer)
                    }
                }
            }
        }
    }

    /// Headline for an offer card — the authored title, falling back to the
    /// generated short label only when no title exists.
    private func offerTitle(_ offer: RestaurantOffer) -> String {
        offer.displayTitle.isEmpty ? offer.shortLabel.text : offer.displayTitle
    }

    /// Description rendered as a bulleted list of its distinct terms.
    @ViewBuilder
    private func termList(_ offer: RestaurantOffer) -> some View {
        let terms = offer.descriptionTerms
        if !terms.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(terms.enumerated()), id: \.offset) { _, term in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").foregroundStyle(Color.pinClayDeep)
                        Text(term).foregroundStyle(Color.pinInk)
                    }
                    .font(.pinSubtitle(12))
                }
            }
        }
    }

    private func dealCard(_ offer: RestaurantOffer) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(offer.shortLabel.emoji + " " + offerTitle(offer))
                    .font(.pinBody(15, weight: .medium))
                    .foregroundStyle(Color.pinClayDeep)
                if let pp = offer.pricePp {
                    Spacer()
                    Text("£\(pp, specifier: "%g")/pp")
                        .font(.pinSubtitle(12).weight(.semibold))
                        .foregroundStyle(Color.pinClayDeep)
                }
            }
            termList(offer)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.pinClay.opacity(0.10)))
    }

    private func groupDealCard(_ offer: RestaurantOffer) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("🔥 " + AppLocalization.string("Group deal"))
                    .font(.pinSubtitle(11).weight(.semibold))
                    .foregroundStyle(Color.pinClayDeep)
                    .textCase(.uppercase)
                if let badge = offer.groupBadge {
                    Text(badge)
                        .font(.pinSubtitle(11).weight(.semibold))
                        .foregroundStyle(Color.pinClayDeep)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.pinClay.opacity(0.25), in: Capsule())
                }
                if let pp = offer.pricePp {
                    Spacer()
                    Text("£\(pp, specifier: "%g")/pp")
                        .font(.pinSubtitle(12).weight(.semibold))
                        .foregroundStyle(Color.pinClayDeep)
                }
            }
            if let min = offer.minPeople {
                Text(String(format: AppLocalization.string("Requires %lld people"), min))
                    .font(.pinSubtitle(12))
                    .foregroundStyle(Color.pinClayDeep)
            }
            Text(offerTitle(offer))
                .font(.pinBody(15, weight: .medium))
                .foregroundStyle(Color.pinInk)
            termList(offer)
            Button {
                AnalyticsService.shared.track("create_plan_click", restaurantId: restaurant.id)
                showCreatePlan = true
            } label: {
                Text("Create table for this deal")
                    .font(.pinButton(14))
                    .foregroundStyle(Color.pinCream)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.pinClay, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.pinClay.opacity(0.15)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.pinClay.opacity(0.4), lineWidth: 2))
    }

    // MARK: - Good to know (curated highlights: price / hours / specialty)

    @ViewBuilder
    private var goodToKnowSection: some View {
        let highlights = displayOffers.filter { $0.category == "highlight" }
        if !highlights.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                PinSectionHeader(title: "Good to know")
                ForEach(highlights) { h in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(h.displayTitle)
                            .font(.pinBody(14, weight: .medium))
                            .foregroundStyle(Color.pinInk)
                        if !h.displayDescription.isEmpty {
                            Text(h.displayDescription)
                                .font(.pinSubtitle(12))
                                .foregroundStyle(Color.pinInkMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Restaurant info (bottom of page)

    @ViewBuilder
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            PinSectionHeader(title: "Restaurant info")
            infoImage
                .padding(.bottom, 4)
            Text(restaurant.displayName)
                .font(.pinBody(18, weight: .medium))
                .foregroundStyle(Color.pinInk)
            // Tap the address to open it in Maps.
            if let mapURL = mapsURL {
                Link(destination: mapURL) {
                    (Text(restaurant.displayCuisine + " · ").foregroundStyle(Color.pinInkMuted)
                     + Text(restaurant.address).foregroundStyle(Color.pinClayDeep).underline())
                        .font(.pinSubtitle(13))
                }
            } else {
                Text(restaurant.displayCuisine + " · " + restaurant.address)
                    .font(.pinSubtitle(13))
                    .foregroundStyle(Color.pinInkMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Apple Maps link for the restaurant's address.
    private var mapsURL: URL? {
        let q = restaurant.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard !q.isEmpty else { return nil }
        return URL(string: "http://maps.apple.com/?q=\(q)")
    }

    /// Restaurant photo for the info section — mirrors web's RestaurantImage:
    /// logos use `contain` on the brand background, food photos use `cover`.
    @ViewBuilder
    private var infoImage: some View {
        let url = restaurant.imageUrl.flatMap { URL(string: $0) }
        Group {
            if restaurant.imageFit == "contain" {
                CachedAsyncImage(url: url, contentMode: .fit,
                                 placeholder: { Rectangle().fill(Color.pinFog) },
                                 failure: { Rectangle().fill(Color.pinFog) })
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(hex: restaurant.imageBg ?? "FFFFFF"))
            } else {
                CachedAsyncImage(url: url,
                                 placeholder: { Rectangle().fill(Color.pinFog) },
                                 failure: { Rectangle().fill(Color.pinFog) })
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 176)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Plan list

    private var planList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                dealsSection

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

                goodToKnowSection.padding(.top, 8)
                infoSection.padding(.top, 8)
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
            AnalyticsService.shared.track("create_plan_click", restaurantId: restaurant.id)
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

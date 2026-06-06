import SwiftUI
import CoreLocation

struct MyPlansView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var unread = UnreadManager.shared
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var userCache = UserCache.shared
    @ObservedObject private var restaurantCache = RestaurantCache.shared
    @State private var plans: [Plan] = []
    @State private var restaurantById: [String: Restaurant] = [:]
    @State private var isLoading = false

    @State private var cuisineFilter: String? = nil
    @State private var statusFilter: PlanStatusFilter = .all
    @State private var sortMode: PlanSortMode = .timeAsc
    @State private var profileTarget: UserProfileSheetTarget?
    @State private var bucket: MyPlansBucket = .active

    enum MyPlansBucket: String, CaseIterable, Identifiable {
        /// Still recruiting — group isn't full yet.
        case active = "Active"
        /// Group is full but the meet-up hasn't started or wrapped up. For
        /// flexible / ASAP plans the organiser still needs to lock in a time
        /// before attendance can be confirmed; for scheduled plans we're just
        /// waiting for the time to arrive (or for the organiser to confirm
        /// attendance after the time passes).
        case ready = "Ready to go"
        /// Attendance was confirmed — the plan is done.
        case completed = "Completed"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pinCream.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                    if isLoading {
                        // Wrapped in a ScrollView so pull-to-refresh works here
                        // too; containerRelativeFrame fills the area so the
                        // spinner/artwork centers like the populated list.
                        ScrollView { loadingState.containerRelativeFrame(.vertical) }
                    } else if visiblePlans.isEmpty {
                        ScrollView { emptyState.containerRelativeFrame(.vertical) }
                    } else {
                        planList
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                Task { await load() }
                startListening()
            }
            .onDisappear { stopListening() }
            .refreshable {
                await load()
                // Keep the tab-bar unread badge fresh on any pull-to-refresh,
                // not just on the Messages tab.
                await UnreadManager.shared.refresh(currentUid: authViewModel.uid)
            }
            .sheet(item: $profileTarget) { target in
                UserProfileView(userId: target.id)
            }
        }
    }

    // MARK: - Realtime
    //
    // Keep My Plans live: any insert/update/delete on `plans` re-fetches so a
    // newly created or joined plan shows up without leaving and re-entering the
    // tab. Cancelled on disappear.
    @State private var listenerTask: Task<Void, Never>?

    private func startListening() {
        guard listenerTask == nil else { return }
        listenerTask = DatabaseService.shared.listenToAllPlanChanges {
            Task { @MainActor in await load() }
        }
    }

    private func stopListening() {
        listenerTask?.cancel()
        listenerTask = nil
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    (
                        Text("My ")
                            .font(.pinHero(28, weight: .light))
                            .foregroundStyle(Color.pinInk)
                        +
                        Text("Plans")
                            .font(.pinAccent(38))
                            .foregroundStyle(Color.pinClayDeep)
                    )
                    .lineLimit(1)
                    Text("Plans I've started or joined.")
                        .font(.pinSubtitle(13))
                        .foregroundStyle(Color.pinInkMuted)
                }
                Spacer()
                filterSortMenu
            }

            PinSegmentedPicker(
                options: [(value: MyPlansBucket.active, label: "Active"),
                          (value: MyPlansBucket.ready, label: "Ready to go"),
                          (value: MyPlansBucket.completed, label: "Completed")],
                counts: bucketCounts,
                selection: $bucket
            )
        }
    }

    /// Per-bucket counts shown as chips on the segmented picker. We only
    /// surface counts for buckets that represent something the user might want
    /// to act on — Completed is intentionally omitted so the picker stays
    /// uncluttered.
    private var bucketCounts: [MyPlansBucket: Int] {
        var active = 0
        var ready = 0
        for plan in plans where plan.attendanceConfirmedAt == nil {
            if plan.needsMorePeople > 0 {
                active += 1
            } else {
                ready += 1
            }
        }
        return [.active: active, .ready: ready]
    }

    private var filterSortMenu: some View {
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
            Image(systemName: filtersActive
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.pinClay)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.pinShell))
        }
        .transaction { $0.animation = nil }
    }

    private var filtersActive: Bool {
        cuisineFilter != nil || statusFilter != .all || sortMode != .timeAsc
    }

    // MARK: - Filter / sort

    private var availableCuisines: [String] {
        Array(Set(restaurantById.values.map(\.cuisine))).sorted()
    }

    private var visiblePlans: [Plan] {
        var result = plans
        switch bucket {
        case .active:
            // Still recruiting.
            result = result.filter { $0.needsMorePeople > 0 && $0.attendanceConfirmedAt == nil }
        case .ready:
            // Group is full, attendance not yet confirmed. Includes flexible /
            // ASAP plans waiting for the organiser to lock a time, scheduled
            // plans waiting for the meet-up to happen, and post-meet plans
            // waiting for the organiser to confirm attendance.
            result = result.filter { $0.needsMorePeople == 0 && $0.attendanceConfirmedAt == nil }
        case .completed:
            // Attendance was confirmed — the plan is done.
            result = result.filter { $0.attendanceConfirmedAt != nil }
        }
        if let cuisine = cuisineFilter, !cuisine.isEmpty {
            result = result.filter { restaurantById[$0.restaurantId]?.cuisine == cuisine }
        }
        if statusFilter != .all {
            result = result.filter { statusFilter.matches($0) }
        }
        switch sortMode {
        case .timeAsc:  result.sort(by: Plan.defaultOrder)
        case .timeDesc: result.sort { $0.scheduledAt > $1.scheduledAt }
        case .nameAsc:
            result.sort {
                let a = restaurantById[$0.restaurantId]?.displayName ?? $0.restaurantName
                let b = restaurantById[$1.restaurantId]?.displayName ?? $1.restaurantName
                return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
            }
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

    // MARK: - List

    /// Plans in the Ready bucket that still have something to wait on — the
    /// organiser hasn't locked a time yet, or the meeting hasn't started.
    ///
    /// Ordering: scheduled-with-future-time plans first (sorted by ASC time,
    /// nearest meet-up at the top), then flexible / ASAP plans needing a
    /// time-lock at the bottom. Inside the no-time group we still sort by
    /// `scheduledAt` for stability.
    private var comingUpPlans: [Plan] {
        let coming = visiblePlans.filter { plan in
            plan.timeType != .scheduled || plan.scheduledAt > Date()
        }
        let ready = coming
            .filter { $0.timeType == .scheduled }
            .sorted { $0.scheduledAt < $1.scheduledAt }
        let needsTime = coming
            .filter { $0.timeType != .scheduled }
            .sorted { $0.scheduledAt < $1.scheduledAt }
        return ready + needsTime
    }

    /// Plans in the Ready bucket where the scheduled time has passed — the
    /// organiser still needs to confirm who actually showed up. Earliest
    /// meet-up first so the most overdue plans bubble to the top of the list.
    private var awaitingConfirmationPlans: [Plan] {
        visiblePlans
            .filter { plan in plan.timeType == .scheduled && plan.scheduledAt <= Date() }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    @ViewBuilder
    private var planList: some View {
        if bucket == .ready {
            readyList
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(visiblePlans) { plan in
                        NavigationLink {
                            PlanDetailView(plan: plan, planVM: PlanViewModel(restaurantId: plan.restaurantId))
                        } label: {
                            planRow(plan)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .padding(.bottom, 24)
            }
            .animation(nil, value: visiblePlans.map(\.id))
        }
    }

    /// Ready-to-go bucket has two sub-sections so it's obvious which pins are
    /// just waiting and which ones need the organiser's attention.
    private var readyList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if !awaitingConfirmationPlans.isEmpty {
                    PinSectionHeader(title: "Confirm attendance to complete")
                        .padding(.top, 6)
                    ForEach(awaitingConfirmationPlans) { plan in
                        NavigationLink {
                            PlanDetailView(plan: plan, planVM: PlanViewModel(restaurantId: plan.restaurantId))
                        } label: {
                            // Pin's already past its scheduled time and needs the
                            // organiser to record who showed up — pin the chip to
                            // that meaning explicitly, regardless of what the plan's
                            // raw state would imply.
                            planRow(plan, chipOverride: ("Confirm attendance", "checkmark.circle", .pinClay))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !comingUpPlans.isEmpty {
                    PinSectionHeader(title: "Coming up")
                        .padding(.top, awaitingConfirmationPlans.isEmpty ? 6 : 10)
                    ForEach(comingUpPlans) { plan in
                        NavigationLink {
                            PlanDetailView(plan: plan, planVM: PlanViewModel(restaurantId: plan.restaurantId))
                        } label: {
                            planRow(plan)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .animation(nil, value: visiblePlans.map(\.id))
    }

    /// Row override type for the status chip. Sub-sections can hard-code the chip
    /// they want a row to show rather than relying on `statusChip(for:)` to
    /// infer it — useful for the "Confirm attendance to complete" sub-section
    /// where the row's section context is the source of truth.
    private typealias ChipOverride = (text: LocalizedStringKey, systemImage: String, tint: Color)

    private func planRow(_ plan: Plan, chipOverride: ChipOverride? = nil) -> some View {
        let hasUnread = UnreadManager.shared.unreadPlanIds.contains(plan.id)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(restaurantCache.displayName(for: plan.restaurantId, fallback: plan.restaurantName))
                    .font(.pinBody(16, weight: .medium))
                    .foregroundStyle(Color.pinInk)
                if hasUnread {
                    Circle()
                        .fill(Color.pinClay)
                        .frame(width: 8, height: 8)
                }
                if plan.hasDeal {
                    PinChip(text: "Deal", systemImage: "tag.fill", tint: .pinSunDeep)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button {
                    profileTarget = UserProfileSheetTarget(id: plan.creatorId)
                } label: {
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
                    }
                }
                .buttonStyle(.plain)

                PinChip(
                    text: plan.creatorId == authViewModel.uid ? "Me — organiser" : "Organiser",
                    tint: .pinClay
                )
            }

            HStack(spacing: 10) {
                Label(plan.timeDisplay, systemImage: "clock")
                    .font(.pinSubtitle(13))
                    .foregroundStyle(Color.pinInkMuted)
                Spacer()
                if let chip = chipOverride {
                    PinChip(text: chip.text, systemImage: chip.systemImage, tint: chip.tint)
                } else {
                    statusChip(for: plan)
                }
            }

            if let created = plan.createdDisplay {
                Text(verbatim: String(format: AppLocalization.string("Created %@"), created))
                    .font(.pinSubtitle(11))
                    .foregroundStyle(Color.pinInkMuted)
            }
        }
        .padding(16)
        .pinCard()
    }

    /// Default chip when the calling section doesn't override. Picks among
    /// "needs people", "needs time", "ready", "confirm attendance" and "done"
    /// based on the plan's state.
    @ViewBuilder
    private func statusChip(for plan: Plan) -> some View {
        if plan.attendanceConfirmedAt != nil {
            PinChip(text: "Done", systemImage: "checkmark.seal.fill", tint: .pinSageDeep)
        } else if plan.needsMorePeople > 0 {
            PinChip(text: "\(plan.currentPeople)/\(plan.neededPeople) joined", systemImage: "person.2.fill", tint: .pinClay)
        } else if plan.timeType != .scheduled {
            // Full but the organiser hasn't locked a time — flexible / ASAP
            // plans can't be confirmed until a specific time is set.
            PinChip(text: "Needs time", systemImage: "clock.badge.questionmark", tint: .pinSunDeep)
        } else if plan.scheduledAt > Date() {
            // Locked time hasn't arrived yet — just sit tight.
            PinChip(text: "Ready", systemImage: "checkmark.seal.fill", tint: .pinSageDeep)
        } else {
            // Past the scheduled time but attendance hasn't been recorded.
            // Organiser sees a confirm-attendance prompt inside the plan.
            PinChip(text: "Confirm attendance", systemImage: "checkmark.circle", tint: .pinClay)
        }
    }

    // MARK: - Empty / loading

    private var emptyState: some View {
        if plans.isEmpty {
            return AnyView(PinEmptyState(
                title: "No pins yet",
                message: "Find a restaurant in Discover and start a pin — or join one my friends started.",
                systemImage: "mappin"
            ))
        }
        switch bucket {
        case .active:
            return AnyView(PinEmptyState(
                title: "Nothing recruiting",
                message: "You're not in any pins still looking for people. Check Ready to go.",
                systemImage: "person.3"
            ))
        case .ready:
            return AnyView(PinEmptyState(
                title: "Nothing ready to go yet",
                message: "Pins move here once the raft is full. Then the organiser locks a time, you meet up, and attendance is confirmed.",
                systemImage: "checkmark.seal"
            ))
        case .completed:
            return AnyView(PinEmptyState(
                title: "No pins wrapped up yet",
                message: "Confirmed plans land here once attendance is recorded.",
                systemImage: "calendar.badge.checkmark"
            ))
        }
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView().tint(Color.pinInkMuted)
            Text("Loading my pins…")
                .font(.pinSubtitle(14))
                .foregroundStyle(Color.pinInkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Load

    private func load() async {
        // Guests can join plans too, so load whenever there's a user (anon or real).
        guard !authViewModel.uid.isEmpty else { return }
        let isFirstLoad = plans.isEmpty
        if isFirstLoad { isLoading = true }
        locationManager.requestPermissionAndStart()
        async let plansTask = DatabaseService.shared.fetchMyPlans(userId: authViewModel.uid)
        async let restaurantsTask = DatabaseService.shared.fetchRestaurants()
        if let fetched = try? await plansTask { plans = fetched }
        if let restaurants = try? await restaurantsTask {
            restaurantById = Dictionary(uniqueKeysWithValues: restaurants.map { ($0.id, $0) })
        }
        await userCache.prefetch(ids: plans.map(\.creatorId))
        isLoading = false
    }
}

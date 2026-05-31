import SwiftUI

enum ChatStreamItem: Identifiable {
    case message(ChatMessage)
    case poll(Poll)

    var id: String {
        switch self {
        case .message(let m): return "m-\(m.id)"
        case .poll(let p):    return "p-\(p.id)"
        }
    }

    var timestamp: Date {
        switch self {
        case .message(let m): return m.timestamp
        case .poll(let p):    return p.createdAt
        }
    }
}

struct PlanDetailView: View {
    let plan: Plan
    @ObservedObject var planVM: PlanViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var chatVM: ChatViewModel
    @StateObject private var pollsVM: PollsViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var showReportSheet = false
    @State private var showCancelConfirm = false
    @State private var showEditSheet = false
    @State private var showPollSheet = false
    @State private var showAttendanceSheet = false
    @State private var showLockTimeSheet = false
    @State private var lockedTime: Date = Date().addingTimeInterval(3600)
    @State private var isBusy = false
    @State private var pendingRemoval: AppUser?
    @State private var profileTarget: UserProfileSheetTarget?
    @ObservedObject private var userCache = UserCache.shared
    @ObservedObject private var restaurantCache = RestaurantCache.shared

    @State private var livePlan: Plan

    init(plan: Plan, planVM: PlanViewModel) {
        self.plan    = plan
        self.planVM  = planVM
        _livePlan    = State(initialValue: plan)
        _chatVM      = StateObject(wrappedValue: ChatViewModel(planId: plan.id))
        _pollsVM     = StateObject(wrappedValue: PollsViewModel(planId: plan.id))
    }

    private var isMember: Bool { livePlan.isMember(uid: authViewModel.uid) }
    private var isOrganiser: Bool { livePlan.creatorId == authViewModel.uid }
    private var canConfirmAttendance: Bool {
        guard isOrganiser else { return false }
        guard livePlan.attendanceConfirmedAt == nil else { return false }
        guard livePlan.needsMorePeople == 0 else { return false }
        guard livePlan.timeType == .scheduled else { return false }
        return livePlan.scheduledAt <= Date()
    }
    private var canLockTime: Bool {
        guard isOrganiser else { return false }
        guard livePlan.attendanceConfirmedAt == nil else { return false }
        guard livePlan.needsMorePeople == 0 else { return false }
        return livePlan.timeType != .scheduled
    }
    private var canAddToCalendar: Bool {
        livePlan.timeType == .scheduled && livePlan.attendanceConfirmedAt == nil
    }

    var body: some View {
        ZStack {
            Color.pinCream.ignoresSafeArea()

            VStack(spacing: 0) {
                planSummary
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.pinShell)

                chatSection

                messageComposer
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(restaurantCache.displayName(for: livePlan.restaurantId, fallback: livePlan.restaurantName))
                    .font(.pinBody(16, weight: .medium))
                    .foregroundStyle(Color.pinInk)
                    .lineLimit(1)
            }
            reportToolbarItem
        }
        .toolbarBackground(Color.pinShell, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showReportSheet) {
            ReportBlockSheet(plan: livePlan, currentUID: authViewModel.uid, isPresented: $showReportSheet)
        }
        .sheet(isPresented: $showEditSheet) {
            CreatePlanView(
                restaurant: Restaurant(id: livePlan.restaurantId, name: livePlan.restaurantName, cuisine: "", address: ""),
                planVM: planVM,
                existingPlan: livePlan
            )
            .environmentObject(authViewModel)
        }
        .confirmationDialog(
            "Cancel this pin?",
            isPresented: $showCancelConfirm,
            titleVisibility: .visible
        ) {
            Button("Cancel pin", role: .destructive) {
                Task {
                    await planVM.cancelPlan(livePlan)
                    dismiss()
                }
            }
            Button("Keep pin", role: .cancel) {}
        } message: {
            Text("Everyone in the raft loses access and the chat goes away.")
        }
        .onAppear {
            chatVM.startListening()
            pollsVM.startListening()
            UnreadManager.shared.markRead(chatId: "plan-\(plan.id)")
            Task { await userCache.prefetch(ids: livePlan.memberIds) }
        }
        .onDisappear {
            chatVM.stopListening()
            pollsVM.stopListening()
            Task { await UnreadManager.shared.refresh(currentUid: authViewModel.uid) }
        }
        .sheet(isPresented: $showPollSheet) {
            CreatePollSheet(pollsVM: pollsVM, isPresented: $showPollSheet)
                .environmentObject(authViewModel)
        }
        .sheet(item: $profileTarget) { target in
            UserProfileView(userId: target.id)
        }
        .onReceive(planVM.$plans) { plans in
            if let updated = plans.first(where: { $0.id == plan.id }) {
                if updated.memberIds != livePlan.memberIds {
                    Task { await userCache.prefetch(ids: updated.memberIds) }
                }
                livePlan = updated
            }
        }
        .confirmationDialog(
            pendingRemoval.map { "Remove \($0.displayName) from the raft?" } ?? "",
            isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { if !$0 { pendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let target = pendingRemoval {
                Button("Remove", role: .destructive) {
                    Task {
                        await planVM.removeMember(
                            plan: livePlan,
                            targetUid: target.id,
                            targetName: target.displayName,
                            removerUid: authViewModel.uid,
                            removerName: authViewModel.displayName
                        )
                    }
                    pendingRemoval = nil
                }
                Button("Keep", role: .cancel) { pendingRemoval = nil }
            }
        }
        .alert("Done", isPresented: Binding(
            get: { planVM.successMessage != nil },
            set: { if !$0 { planVM.successMessage = nil } }
        )) {
            Button("OK", role: .cancel) { planVM.successMessage = nil }
        } message: { Text(planVM.successMessage ?? "") }
        .alert("Heads up", isPresented: Binding(
            get: { pollsVM.errorMessage != nil },
            set: { if !$0 { pollsVM.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { pollsVM.errorMessage = nil }
        } message: { Text(pollsVM.errorMessage ?? "") }
        .sheet(isPresented: $showAttendanceSheet) {
            ConfirmAttendanceSheet(
                plan: livePlan,
                isPresented: $showAttendanceSheet,
                onConfirmed: { Task { await planVM.refresh() } }
            )
        }
        .sheet(isPresented: $showLockTimeSheet) {
            lockTimeSheet
        }
    }

    // MARK: - Plan summary

    private var planSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label(livePlan.timeDisplay, systemImage: "clock")
                    .font(.pinBody(15, weight: .medium))
                    .foregroundStyle(Color.pinInk)
                Spacer()
                Text("\(livePlan.currentPeople)/\(livePlan.neededPeople)")
                    .font(.pinBody(13, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color.pinInkMuted)
            }

            HStack(spacing: 8) {
                if livePlan.needsMorePeople > 0 {
                    PinChip(text: "Needs \(livePlan.needsMorePeople) more",
                            systemImage: "person.3.fill", tint: .pinClay)
                } else {
                    PinChip(text: "Group is full",
                            systemImage: "checkmark.seal.fill", tint: .pinSageDeep)
                }
                if livePlan.genderPreference != .any {
                    // Pass the English source key directly; PinChip's
                    // LocalizedStringKey type does the catalog lookup. Don't
                    // pre-translate via NSLocalizedString here — that'd hand
                    // the chip a runtime String which can't be re-localised.
                    PinChip(text: LocalizedStringKey(livePlan.genderPreference.label),
                            systemImage: "person.crop.circle.fill",
                            tint: .pinLavenderDeep)
                }
                if livePlan.attendanceConfirmedAt != nil {
                    PinChip(text: "Confirmed", systemImage: "checkmark.seal.fill", tint: .pinSageDeep)
                }
            }

            if !livePlan.notes.isEmpty {
                Text(livePlan.notes)
                    .font(.pinBody(13))
                    .foregroundStyle(Color.pinInkMuted)
                    .padding(.top, 2)
            }

            primaryActions
            membersStrip
            joinLeaveButton
        }
    }

    @ViewBuilder
    private var primaryActions: some View {
        VStack(spacing: 8) {
            if canLockTime {
                Button {
                    lockedTime = max(Date().addingTimeInterval(1800), livePlan.scheduledAt)
                    showLockTimeSheet = true
                } label: {
                    Label("Lock in the time", systemImage: "clock.badge.checkmark")
                }
                .buttonStyle(PinPrimaryButtonStyle(size: 14))
            } else if canConfirmAttendance {
                Button {
                    showAttendanceSheet = true
                } label: {
                    Label("Confirm attendance", systemImage: "checkmark.seal.fill")
                }
                .buttonStyle(PinPrimaryButtonStyle(size: 14))
            }

            if canAddToCalendar {
                Button {
                    Task {
                        do { try await CalendarService.shared.addPlanToCalendar(plan: livePlan) }
                        catch { print("[DEBUG] calendar add failed: \(error)") }
                    }
                } label: {
                    Label("Add to calendar", systemImage: "calendar.badge.plus")
                        .font(.pinButton(13))
                        .foregroundStyle(Color.pinClayDeep)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.pinClay.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, livePlan.needsMorePeople == 0 || canConfirmAttendance || canLockTime || canAddToCalendar ? 4 : 0)
    }

    private var membersStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Sun-yellow accent — "raft" is the group concept; tinting the label
            // ties this section to the Raft chip in the Messages list.
            HStack(spacing: 5) {
                Image(systemName: "sailboat.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.pinSunDeep)
                Text("Your raft")
                    .font(.pinBody(11, weight: .medium))
                    .foregroundStyle(Color.pinSunDeep)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(livePlan.memberIds, id: \.self) { uid in
                        memberChip(uid: uid)
                    }
                }
            }
        }
    }

    private func memberChip(uid: String) -> some View {
        let isThisOrganiser = uid == livePlan.creatorId
        let canRemove = isOrganiser && !isThisOrganiser
        let liveName = userCache.name(for: uid, fallback: AppLocalization.string("Diner"))
        return HStack(spacing: 6) {
            Button {
                profileTarget = UserProfileSheetTarget(id: uid)
            } label: {
                HStack(spacing: 6) {
                    LiveAvatar(userId: uid, size: 22, fontSize: 10)
                    Text(liveName)
                        .font(.pinBody(12))
                        .foregroundStyle(Color.pinInk)
                        .lineLimit(1)
                    if isThisOrganiser {
                        Image(systemName: "crown.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.pinClay)
                    }
                }
            }
            .buttonStyle(.plain)
            if canRemove {
                Button {
                    if let member = userCache.user(for: uid) {
                        pendingRemoval = member
                    } else {
                        pendingRemoval = AppUser(id: uid, email: "", displayName: liveName)
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.pinClayDeep)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(Color.pinCream))
    }

    @ViewBuilder
    private var joinLeaveButton: some View {
        HStack(spacing: 10) {
            if isBusy {
                Spacer()
                ProgressView().tint(Color.pinClay)
                Spacer()
            } else if isMember {
                Button {
                    Task { await toggleMembership() }
                } label: {
                    Label("Leave", systemImage: "arrow.uturn.left")
                        .font(.pinButton(14))
                        .foregroundStyle(Color.pinClayDeep)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.pinClay.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)

                if isOrganiser {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .font(.pinButton(14))
                            .foregroundStyle(Color.pinInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.pinCream)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showCancelConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.pinCream)
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.pinClayDeep)
                            )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    Task { await toggleMembership() }
                } label: {
                    Label("Join this pin", systemImage: "plus.circle.fill")
                }
                .buttonStyle(PinPrimaryButtonStyle(size: 14))
                .disabled(livePlan.needsMorePeople == 0)
                .opacity(livePlan.needsMorePeople == 0 ? 0.5 : 1)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Chat stream

    private var streamItems: [ChatStreamItem] {
        let msgs = chatVM.messages.map { ChatStreamItem.message($0) }
        let polls = pollsVM.polls.map { ChatStreamItem.poll($0) }
        return (msgs + polls).sorted { $0.timestamp < $1.timestamp }
    }

    private var chatSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(streamItems) { item in
                        streamRow(item)
                            .id(item.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .refreshable {
                await planVM.refresh()
                await chatVM.refresh()
                await pollsVM.load()
                await UnreadManager.shared.refresh(currentUid: authViewModel.uid)
            }
            .onChange(of: streamItems.count) { _, _ in
                if let lastId = streamItems.last?.id {
                    withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                }
            }
        }
    }

    @ViewBuilder
    private func streamRow(_ item: ChatStreamItem) -> some View {
        switch item {
        case .message(let msg):
            ChatBubbleView(
                message: msg,
                isCurrentUser: msg.senderId == authViewModel.uid,
                onAvatarTap: { uid in profileTarget = UserProfileSheetTarget(id: uid) }
            )
        case .poll(let poll):
            PollCardView(
                poll: poll,
                votes: pollsVM.votesByPoll[poll.id] ?? [],
                currentUid: authViewModel.uid,
                onVote: { index in
                    Task { await pollsVM.vote(pollId: poll.id, optionIndex: index, userId: authViewModel.uid) }
                }
            )
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Composer

    private var messageComposer: some View {
        HStack(spacing: 10) {
            Button {
                showPollSheet = true
            } label: {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(isMember ? Color.pinClay : Color.pinInkMuted.opacity(0.4))
            }
            .disabled(!isMember)

            TextField("Message…", text: $chatVM.draftText)
                .font(.pinBody(15))
                .foregroundStyle(Color.pinInk)
                .tint(Color.pinClay)
                .submitLabel(.send)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.pinShell)
                )
                .onSubmit { chatVM.send(senderId: authViewModel.uid) }

            Button {
                chatVM.send(senderId: authViewModel.uid)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.pinCream)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(
                            chatVM.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.pinInkMuted.opacity(0.4)
                                : Color.pinClay
                        )
                    )
            }
            .buttonStyle(.plain)
            .disabled(chatVM.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.pinCream)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.pinFog).frame(height: 1)
        }
    }

    // MARK: - Toolbar

    private var reportToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button(role: .destructive) {
                    showReportSheet = true
                } label: {
                    Label("Report / Block", systemImage: "flag")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.pinInk)
            }
        }
    }

    // MARK: - Lock-time sheet

    private var lockTimeSheet: some View {
        NavigationStack {
            ZStack {
                Color.pinCream.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text("Lock in the meet-up time")
                        .font(.pinBody(13, weight: .medium))
                        .foregroundStyle(Color.pinInkMuted)
                    DatePicker("",
                               selection: $lockedTime,
                               in: Date()...,
                               displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                        .tint(Color.pinClay)
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showLockTimeSheet = false }
                        .font(.pinButton(15))
                        .foregroundStyle(Color.pinInk)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lock") {
                        Task {
                            try? await DatabaseService.shared.setPlanScheduledTime(planId: livePlan.id, scheduledAt: lockedTime)
                            await planVM.refresh()
                            showLockTimeSheet = false
                        }
                    }
                    .font(.pinButton(15))
                    .foregroundStyle(Color.pinClay)
                }
            }
            .toolbarBackground(Color.pinCream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    // MARK: - Actions

    private func toggleMembership() async {
        isBusy = true
        if isMember {
            await planVM.leave(plan: livePlan,
                               userId: authViewModel.uid,
                               userName: authViewModel.displayName)
        } else {
            await planVM.join(plan: livePlan,
                              userId: authViewModel.uid,
                              userName: authViewModel.displayName)
        }
        isBusy = false
    }
}

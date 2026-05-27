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

    // Keep a live copy of the plan so member list changes reflect in UI
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
        // Only after a specific time is locked in AND that time has passed.
        guard livePlan.timeType == .scheduled else { return false }
        return livePlan.scheduledAt <= Date()
    }

    /// Organiser sees a "Lock in Time" CTA when the plan is full but no specific time has been set.
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
        VStack(spacing: 0) {
            // Plan summary header
            planSummary
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemGroupedBackground))

            Divider()

            // Combined chat + polls stream
            chatSection

            // Message composer
            messageComposer
        }
        .navigationTitle(restaurantCache.displayName(for: livePlan.restaurantId, fallback: livePlan.restaurantName))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { reportToolbarItem }
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
            "Cancel this plan for everyone?",
            isPresented: $showCancelConfirm,
            titleVisibility: .visible
        ) {
            Button("Cancel Plan", role: .destructive) {
                Task {
                    await planVM.cancelPlan(livePlan)
                    dismiss()
                }
            }
            Button("Keep Plan", role: .cancel) {}
        } message: {
            Text("All members will lose access and the chat will be deleted.")
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
            pendingRemoval.map { "Remove \($0.displayName) from the plan?" } ?? "",
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
        } message: {
            Text(planVM.successMessage ?? "")
        }
        .alert("Error", isPresented: Binding(
            get: { pollsVM.errorMessage != nil },
            set: { if !$0 { pollsVM.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { pollsVM.errorMessage = nil }
        } message: {
            Text(pollsVM.errorMessage ?? "")
        }
        .sheet(isPresented: $showAttendanceSheet) {
            ConfirmAttendanceSheet(
                plan: livePlan,
                isPresented: $showAttendanceSheet,
                onConfirmed: {
                    Task { await planVM.refresh() }
                }
            )
        }
        .sheet(isPresented: $showLockTimeSheet) {
            NavigationStack {
                Form {
                    Section("Lock in the meet-up time") {
                        DatePicker("Time",
                                   selection: $lockedTime,
                                   in: Date()...,
                                   displayedComponents: [.date, .hourAndMinute])
                    }
                }
                .navigationTitle("Lock in Time")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showLockTimeSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Lock") {
                            Task {
                                try? await DatabaseService.shared.setPlanScheduledTime(planId: livePlan.id, scheduledAt: lockedTime)
                                await planVM.refresh()
                                showLockTimeSheet = false
                            }
                        }
                        .bold()
                    }
                }
            }
        }
    }

    // MARK: - Plan summary header

    private var planSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(livePlan.timeDisplay, systemImage: "clock")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 6) {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.orange)
                if livePlan.needsMorePeople > 0 {
                    Text("Need \(livePlan.needsMorePeople) more")
                        .foregroundColor(.orange)
                } else {
                    Text("Group is full")
                        .foregroundColor(.green)
                }
                Spacer()
                Text("\(livePlan.currentPeople)/\(livePlan.neededPeople)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)

            if livePlan.genderPreference != .any {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundColor(.pink)
                    Text(LocalizedStringKey(livePlan.genderPreference.label))
                        .font(.caption.bold())
                        .foregroundColor(.pink)
                }
            }

            if canLockTime {
                Button {
                    lockedTime = max(Date().addingTimeInterval(1800), livePlan.scheduledAt)
                    showLockTimeSheet = true
                } label: {
                    Label("Lock in Time", systemImage: "clock.badge.checkmark")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            } else if canConfirmAttendance {
                Button {
                    showAttendanceSheet = true
                } label: {
                    Label("Confirm Attendance", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            } else if livePlan.attendanceConfirmedAt != nil {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("Attendance confirmed")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                }
            }

            if canAddToCalendar {
                Button {
                    Task {
                        do { try await CalendarService.shared.addPlanToCalendar(plan: livePlan) }
                        catch { print("[DEBUG] calendar add failed: \(error)") }
                    }
                } label: {
                    Label("Add to Calendar", systemImage: "calendar.badge.plus")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .tint(.blue)
            }

            if !livePlan.notes.isEmpty {
                Text(livePlan.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            membersList

            // Join / Leave
            joinLeaveButton
        }
    }

    private var membersList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Members")
                .font(.caption.bold())
                .foregroundColor(.secondary)
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
        let liveName = userCache.name(for: uid, fallback: "Diner")
        return HStack(spacing: 6) {
            Button {
                profileTarget = UserProfileSheetTarget(id: uid)
            } label: {
                HStack(spacing: 6) {
                    LiveAvatar(userId: uid, size: 24, fontSize: 11)
                    Text(liveName)
                        .font(.caption)
                        .lineLimit(1)
                    if isThisOrganiser {
                        Image(systemName: "crown.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            .buttonStyle(.plain)
            if canRemove {
                Button {
                    if let member = userCache.user(for: uid) {
                        pendingRemoval = member
                    } else {
                        // Synthesise a minimal AppUser so the confirmation dialog can still name them.
                        pendingRemoval = AppUser(id: uid, email: "", displayName: liveName)
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.tertiarySystemFill))
        .clipShape(Capsule())
    }

    private var joinLeaveButton: some View {
        HStack(spacing: 10) {
            if isBusy {
                Spacer()
                ProgressView()
                Spacer()
            } else if isMember {
                Button {
                    Task { await toggleMembership() }
                } label: {
                    Label("Leave", systemImage: "arrow.uturn.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)

                if isOrganiser {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)

                    Button {
                        showCancelConfirm = true
                    } label: {
                        Label("Cancel", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            } else {
                Button {
                    Task { await toggleMembership() }
                } label: {
                    Label("Join Plan", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(livePlan.needsMorePeople == 0)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Chat

    /// Combined timeline of messages and polls so polls scroll naturally with chat.
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
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .refreshable {
                await planVM.refresh()
                await chatVM.refresh()
                await pollsVM.load()
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

    // MARK: - Message composer

    private var messageComposer: some View {
        HStack(spacing: 10) {
            Button {
                showPollSheet = true
            } label: {
                Image(systemName: "chart.bar.fill")
                    .font(.title3)
                    .foregroundColor(.orange)
            }
            .disabled(!isMember)

            TextField("Message…", text: $chatVM.draftText)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit {
                    chatVM.send(senderId: authViewModel.uid)
                }

            Button {
                chatVM.send(senderId: authViewModel.uid)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(chatVM.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .orange)
            }
            .disabled(chatVM.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
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
            }
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

import SwiftUI

struct PlanDetailView: View {
    let plan: Plan
    @ObservedObject var planVM: PlanViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var chatVM: ChatViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var showReportSheet = false
    @State private var showCancelConfirm = false
    @State private var showEditSheet = false
    @State private var isBusy = false
    @State private var members: [AppUser] = []
    @State private var pendingRemoval: AppUser?

    // Keep a live copy of the plan so member list changes reflect in UI
    @State private var livePlan: Plan

    init(plan: Plan, planVM: PlanViewModel) {
        self.plan    = plan
        self.planVM  = planVM
        _livePlan    = State(initialValue: plan)
        _chatVM      = StateObject(wrappedValue: ChatViewModel(planId: plan.id))
    }

    private var isMember: Bool { livePlan.isMember(uid: authViewModel.uid) }
    private var isOrganiser: Bool { livePlan.creatorId == authViewModel.uid }

    var body: some View {
        VStack(spacing: 0) {
            // Plan summary header
            planSummary
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemGroupedBackground))

            Divider()

            // Real-time chat
            chatSection

            // Message composer
            messageComposer
        }
        .navigationTitle(livePlan.restaurantName)
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
            UnreadManager.shared.markRead(chatId: "plan-\(plan.id)")
            Task { await loadMembers() }
        }
        .onDisappear {
            chatVM.stopListening()
            Task { await UnreadManager.shared.refresh(currentUid: authViewModel.uid) }
        }
        .onReceive(planVM.$plans) { plans in
            if let updated = plans.first(where: { $0.id == plan.id }) {
                if updated.memberIds != livePlan.memberIds {
                    Task { await loadMembers() }
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
                            removerName: authViewModel.displayName
                        )
                        await loadMembers()
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
                    ForEach(members) { member in
                        memberChip(member)
                    }
                }
            }
        }
    }

    private func memberChip(_ member: AppUser) -> some View {
        let isThisOrganiser = member.id == livePlan.creatorId
        let canRemove = isOrganiser && !isThisOrganiser
        return HStack(spacing: 6) {
            AvatarImage(urlString: member.avatarURL, name: member.displayName, size: 24, fontSize: 11)
            Text(member.displayName)
                .font(.caption)
                .lineLimit(1)
            if isThisOrganiser {
                Image(systemName: "crown.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            if canRemove {
                Button {
                    pendingRemoval = member
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

    private func loadMembers() async {
        guard let fetched = try? await DatabaseService.shared.fetchUsers(ids: livePlan.memberIds) else { return }
        // Keep order matching memberIds (so organiser first)
        let byId = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
        members = livePlan.memberIds.compactMap { byId[$0] }
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

    private var chatSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(chatVM.messages) { msg in
                        ChatBubbleView(message: msg, isCurrentUser: msg.senderId == authViewModel.uid)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .refreshable {
                await planVM.refresh()
                await chatVM.refresh()
            }
            .onChange(of: chatVM.messages.count) { _, _ in
                if let lastId = chatVM.messages.last?.id {
                    withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Message composer

    private var messageComposer: some View {
        HStack(spacing: 10) {
            TextField("Message…", text: $chatVM.draftText)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit {
                    chatVM.send(senderId: authViewModel.uid, senderName: authViewModel.displayName, senderAvatarURL: authViewModel.avatarURL)
                }

            Button {
                chatVM.send(senderId: authViewModel.uid, senderName: authViewModel.displayName, senderAvatarURL: authViewModel.avatarURL)
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

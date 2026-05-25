import SwiftUI

struct PlanDetailView: View {
    let plan: Plan
    @ObservedObject var planVM: PlanViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var chatVM: ChatViewModel

    @State private var showReportSheet = false
    @State private var isBusy = false

    // Keep a live copy of the plan so member list changes reflect in UI
    @State private var livePlan: Plan

    init(plan: Plan, planVM: PlanViewModel) {
        self.plan    = plan
        self.planVM  = planVM
        _livePlan    = State(initialValue: plan)
        _chatVM      = StateObject(wrappedValue: ChatViewModel(planId: plan.id))
    }

    private var isMember: Bool { livePlan.isMember(uid: authViewModel.uid) }

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
        .onAppear {
            chatVM.startListening()
        }
        .onDisappear {
            chatVM.stopListening()
        }
        .onReceive(planVM.$plans) { plans in
            if let updated = plans.first(where: { $0.id == plan.id }) {
                livePlan = updated
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
                PurposeTag(purpose: livePlan.purpose)
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

            // Join / Leave
            joinLeaveButton
        }
    }

    private var joinLeaveButton: some View {
        HStack {
            Spacer()
            if isBusy {
                ProgressView()
            } else if isMember {
                Button {
                    Task { await toggleMembership() }
                } label: {
                    Label("Leave Plan", systemImage: "arrow.uturn.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
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
            TextField("Message…", text: $chatVM.draftText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)

            Button {
                chatVM.send(senderId: authViewModel.uid, senderName: authViewModel.displayName)
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

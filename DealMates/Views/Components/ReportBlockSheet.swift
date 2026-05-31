import SwiftUI

/// Sheet with options to report a plan or block the plan's organiser.
struct ReportBlockSheet: View {
    let plan: Plan
    let currentUID: String
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var isPresented: Bool

    @State private var showConfirmation = false
    @State private var pendingAction: Action?
    @ObservedObject private var cache = UserCache.shared

    enum Action: String {
        case reportPlan  = "Report this pin"
        case blockUser   = "Block this puffin"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pinCream.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    VStack(spacing: 0) {
                        reportButton
                        Divider().background(Color.pinFog).padding(.leading, 58)
                        blockButton
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.pinShell)
                    )

                    Text("Reported content is reviewed by moderators. Repeated misuse may result in removal from PinTable.")
                        .font(.pinSubtitle(12))
                        .foregroundStyle(Color.pinInkMuted)
                        .padding(.horizontal, 6)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Report or block")
                        .font(.pinBody(15, weight: .medium))
                        .foregroundStyle(Color.pinInk)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .font(.pinButton(15))
                        .foregroundStyle(Color.pinInk)
                }
            }
            .toolbarBackground(Color.pinCream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert("Are you sure?", isPresented: $showConfirmation, presenting: pendingAction) { action in
                Button("Confirm", role: .destructive) { perform(action) }
                Button("Cancel", role: .cancel) { }
            } message: { action in
                Text(action.rawValue)
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Buttons

    private var reportButton: some View {
        let alreadyReported = authViewModel.hasReported(planId: plan.id)
        return Button {
            pendingAction = .reportPlan
            showConfirmation = true
        } label: {
            actionRow(
                icon: "flag.fill",
                tint: .pinClayDeep,
                label: alreadyReported ? "Pin already reported" : "Report this pin",
                disabled: alreadyReported
            )
        }
        .buttonStyle(.plain)
        .disabled(alreadyReported)
    }

    private var blockButton: some View {
        let alreadyBlocked = authViewModel.hasBlocked(uid: plan.creatorId)
        let creatorName = cache.name(for: plan.creatorId, fallback: plan.creatorName)
        return Button {
            pendingAction = .blockUser
            showConfirmation = true
        } label: {
            actionRow(
                icon: "person.fill.xmark",
                tint: .pinClay,
                label: alreadyBlocked ? "Puffin already blocked" : "Block \(creatorName)",
                disabled: alreadyBlocked || plan.creatorId == currentUID
            )
        }
        .buttonStyle(.plain)
        .disabled(alreadyBlocked || plan.creatorId == currentUID)
    }

    private func actionRow(icon: String, tint: Color, label: LocalizedStringKey, disabled: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(disabled ? Color.pinInkMuted : tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill((disabled ? Color.pinInkMuted : tint).opacity(0.16)))
            Text(label)
                .font(.pinBody(14))
                .foregroundStyle(disabled ? Color.pinInkMuted : Color.pinInk)
            Spacer()
        }
        .padding(14)
    }

    // MARK: - Action

    private func perform(_ action: Action) {
        Task {
            switch action {
            case .reportPlan:
                await authViewModel.reportPlan(id: plan.id)
            case .blockUser:
                await authViewModel.blockUser(uid: plan.creatorId)
            }
            isPresented = false
        }
    }
}

import SwiftUI

// MARK: - ReportBlockSheet
/// Stub sheet with options to report a plan or block the plan creator.
struct ReportBlockSheet: View {
    let plan: Plan
    let currentUID: String
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var isPresented: Bool

    @State private var showConfirmation = false
    @State private var pendingAction: Action?

    enum Action: String {
        case reportPlan  = "Report this plan"
        case blockUser   = "Block this diner"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    reportButton
                    blockButton
                } footer: {
                    Text("Reported content is reviewed by moderators. Repeated misuse may result in removal from DealMates.")
                        .font(.caption)
                }
            }
            .navigationTitle("Report / Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
            .alert("Are you sure?", isPresented: $showConfirmation, presenting: pendingAction) { action in
                Button("Confirm", role: .destructive) { perform(action) }
                Button("Cancel", role: .cancel) { }
            } message: { action in
                Text(action.rawValue)
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: Buttons

    private var reportButton: some View {
        let alreadyReported = authViewModel.hasReported(planId: plan.id)
        return Button {
            pendingAction = .reportPlan
            showConfirmation = true
        } label: {
            Label(alreadyReported ? "Plan already reported" : "Report this plan",
                  systemImage: "flag.fill")
            .foregroundColor(alreadyReported ? .secondary : .red)
        }
        .disabled(alreadyReported)
    }

    private var blockButton: some View {
        let alreadyBlocked = authViewModel.hasBlocked(uid: plan.creatorId)
        return Button {
            pendingAction = .blockUser
            showConfirmation = true
        } label: {
            Label(alreadyBlocked ? "User already blocked" : "Block \(plan.creatorName)",
                  systemImage: "person.fill.xmark")
            .foregroundColor(alreadyBlocked ? .secondary : .orange)
        }
        .disabled(alreadyBlocked || plan.creatorId == currentUID)
    }

    // MARK: Action handler

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

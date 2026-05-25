import SwiftUI

// MARK: - MyPlansView

struct MyPlansView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var plans: [Plan] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading your plans…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if plans.isEmpty {
                    emptyState
                } else {
                    planList
                }
            }
            .navigationTitle("My Plans")
            .task { await load() }
            .refreshable { await load() }
        }
    }

    // MARK: - Sub-views

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text("No active plans yet")
                .font(.headline)
            Text("Join or create a plan from the Discover tab.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var planList: some View {
        List(plans) { plan in
            NavigationLink(destination: PlanDetailView(plan: plan, planVM: PlanViewModel(restaurantId: plan.restaurantId))) {
                planRow(plan)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func planRow(_ plan: Plan) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(plan.restaurantName)
                .font(.headline)
            HStack(spacing: 8) {
                Label(plan.timeDisplay, systemImage: "clock")
                Spacer()
                Label(plan.purpose.label, systemImage: plan.purpose.icon)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)

            if plan.needsMorePeople > 0 {
                Text("Needs \(plan.needsMorePeople) more")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .bold()
            } else {
                Text("Ready to go!")
                    .font(.caption)
                    .foregroundColor(.green)
                    .bold()
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Load

    private func load() async {
        guard authViewModel.isSignedIn else { return }
        isLoading = true
        plans = (try? await DatabaseService.shared.fetchMyActivePlans(userId: authViewModel.uid)) ?? []
        isLoading = false
    }
}

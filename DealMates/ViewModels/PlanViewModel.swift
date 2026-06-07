import SwiftUI
import Combine

@MainActor
final class PlanViewModel: ObservableObject {
    @Published var plans: [Plan] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    let restaurantId: String
    private var listenerTask: Task<Void, Never>?
    private let service = DatabaseService.shared

    init(restaurantId: String) {
        self.restaurantId = restaurantId
    }

    deinit { listenerTask?.cancel() }

    // MARK: - Listener

    func startListening() {
        // Idempotent: cancel any previous listener so re-entering the view
        // doesn't open duplicate realtime channels.
        listenerTask?.cancel()
        // Only show the full-screen spinner on the very first load — auto-
        // refresh-on-appear (RestaurantBoardView.onAppear) calls this on every
        // re-entry, and flickering `isLoading` would swap the body shape and
        // break any in-progress pull-to-refresh.
        if plans.isEmpty { isLoading = true }
        Task { await fetchPlans() }

        listenerTask = service.listenToPlans(restaurantId: restaurantId) { [weak self] in
            await self?.fetchPlans()
        }
    }

    func stopListening() {
        listenerTask?.cancel()
        listenerTask = nil
    }

    // MARK: - Actions

    func createPlan(_ plan: Plan) async throws {
        try await service.createPlan(plan)
        await fetchPlans()
        successMessage = AppLocalization.string("Plan created!")
    }

    func updatePlan(_ plan: Plan) async throws {
        try await service.updatePlan(plan)
        await fetchPlans()
        successMessage = AppLocalization.string("Plan updated")
    }

    func refresh() async {
        await fetchPlans()
    }

    func removeMember(plan: Plan, targetUid: String, targetName: String,
                      removerUid: String, removerName: String) async {
        do {
            try await service.removeMember(plan,
                                           targetUid: targetUid, targetName: targetName,
                                           removerUid: removerUid, removerName: removerName)
            await fetchPlans()
            // "Removed %@" lives in the catalog; AppLocalization returns the
            // format string in the current language, then String(format:) fills
            // in the name.
            successMessage = String(
                format: AppLocalization.string("Removed %@"),
                targetName
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelPlan(_ plan: Plan) async {
        do {
            try await service.deletePlan(planId: plan.id)
            plans.removeAll { $0.id == plan.id }
            successMessage = AppLocalization.string("Plan cancelled")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func join(plan: Plan, userId: String, userName: String) async {
        AnalyticsService.shared.track("join_click", restaurantId: plan.restaurantId, planId: plan.id)
        do {
            try await service.joinPlan(plan, userId: userId, userName: userName)
            await fetchPlans()
            successMessage = AppLocalization.string("I joined the plan!")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func leave(plan: Plan, userId: String, userName: String) async {
        do {
            try await service.leavePlan(plan, userId: userId, userName: userName)
            await fetchPlans()
            successMessage = AppLocalization.string("I left the plan")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private

    private func fetchPlans() async {
        guard let fresh = try? await service.fetchActivePlans(restaurantId: restaurantId) else { return }
        plans = fresh
        isLoading = false
    }
}

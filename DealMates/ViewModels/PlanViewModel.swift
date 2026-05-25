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
        isLoading = true
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
    }

    func join(plan: Plan, userId: String, userName: String) async {
        do {
            try await service.joinPlan(plan, userId: userId, userName: userName)
            successMessage = "✅ You joined the plan!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.successMessage = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func leave(plan: Plan, userId: String, userName: String) async {
        do {
            try await service.leavePlan(plan, userId: userId, userName: userName)
            successMessage = "✅ You left the plan"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.successMessage = nil
            }
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

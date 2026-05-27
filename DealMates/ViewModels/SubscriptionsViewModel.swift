import SwiftUI
import Combine

@MainActor
final class SubscriptionsViewModel: ObservableObject {
    static let shared = SubscriptionsViewModel()
    @Published var subscribedRestaurantIds: Set<String> = []

    private let service = DatabaseService.shared

    func load(currentUid: String) async {
        guard !currentUid.isEmpty else { return }
        do {
            let subs = try await service.fetchSubscriptions(userId: currentUid)
            subscribedRestaurantIds = Set(subs.map(\.restaurantId))
        } catch {
            print("[DEBUG] SubscriptionsViewModel.load failed: \(error)")
        }
    }

    func isSubscribed(restaurantId: String) -> Bool {
        subscribedRestaurantIds.contains(restaurantId)
    }

    func toggle(restaurantId: String, currentUid: String) async {
        guard !currentUid.isEmpty else { return }
        if subscribedRestaurantIds.contains(restaurantId) {
            try? await service.unsubscribeFromRestaurant(userId: currentUid, restaurantId: restaurantId)
            subscribedRestaurantIds.remove(restaurantId)
        } else {
            try? await service.subscribeToRestaurant(userId: currentUid, restaurantId: restaurantId)
            subscribedRestaurantIds.insert(restaurantId)
        }
        await NotificationManager.shared.refreshSubscriptions()
    }
}

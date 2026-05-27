import Foundation
import UIKit
import UserNotifications
import Combine

enum NotificationPreference: String, CaseIterable, Identifiable {
    case off, subscribed, all
    var id: String { rawValue }
    var label: String {
        switch self {
        case .off:        return "Off"
        case .subscribed: return "Subscribed restaurants only"
        case .all:        return "All new plans"
        }
    }
}

/// Local-notification manager. Listens for new plan inserts across all restaurants and posts a
/// `UNNotificationRequest` when one matches the user's notification preference.
@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published private(set) var subscribedRestaurantIds: Set<String> = []
    private var listenerTask: Task<Void, Never>?
    private var currentUid: String = ""

    private init() {}

    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        if let granted = try? await center.requestAuthorization(options: [.alert, .badge, .sound]), granted {
            // Try to register for remote push. Silently no-ops if the Push Notifications capability
            // isn't attached / Apple Developer Program isn't enrolled — local notifications still work.
            await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    func startListening(currentUid: String) {
        self.currentUid = currentUid
        Task { await refreshSubscriptions() }
        stopListening()
        listenerTask = DatabaseService.shared.listenToAllPlanInserts { [weak self] plan in
            self?.handleNewPlan(plan)
        }
    }

    func stopListening() {
        listenerTask?.cancel()
        listenerTask = nil
    }

    func refreshSubscriptions() async {
        guard !currentUid.isEmpty else { return }
        let subs = (try? await DatabaseService.shared.fetchSubscriptions(userId: currentUid)) ?? []
        subscribedRestaurantIds = Set(subs.map(\.restaurantId))
    }

    private func handleNewPlan(_ plan: Plan) {
        let pref = NotificationPreference(rawValue: UserDefaults.standard.string(forKey: "notification_preference") ?? "subscribed") ?? .subscribed
        // Don't notify about your own plan creation.
        guard plan.creatorId != currentUid else { return }
        switch pref {
        case .off:
            return
        case .subscribed:
            guard subscribedRestaurantIds.contains(plan.restaurantId) else { return }
        case .all:
            break
        }
        post(plan: plan)
    }

    private func post(plan: Plan) {
        let content = UNMutableNotificationContent()
        content.title = "New plan at \(plan.restaurantName)"
        content.body = "\(plan.creatorName) just created a plan — \(plan.timeDisplay)"
        content.sound = .default
        let req = UNNotificationRequest(identifier: "plan-\(plan.id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}


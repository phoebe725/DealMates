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

/// Posts local user notifications so the user gets alerted to relevant
/// activity even when the app is foregrounded. Listens to three realtime
/// streams:
///
///   • Plan inserts → new-plan alert (filtered by the user's `notification_preference`)
///   • Plan updates → "X joined your pin" when membership grows, and
///                     "Your raft is ready" when the raft just hit full
///
/// The plan-update path needs the *previous* member list to diff against, so
/// we hold an in-memory `planCache` keyed by plan id. It's populated from
/// `fetchMyActivePlans` on `startListening` and kept in sync via the realtime
/// callbacks.
@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published private(set) var subscribedRestaurantIds: Set<String> = []

    private var planInsertTask: Task<Void, Never>?
    private var planUpdateTask: Task<Void, Never>?
    private var currentUid: String = ""
    private var planCache: [String: Plan] = [:]

    private init() {}

    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        // Log the current permission status before prompting — if the user
        // previously denied, the prompt won't reappear and we need to see that
        // in the console.
        let preSettings = await center.notificationSettings()
        print("[DEBUG] NotificationManager: pre-prompt auth status = \(preSettings.authorizationStatus.rawValue)")

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            print("[DEBUG] NotificationManager: requestAuthorization granted = \(granted)")
            if granted {
                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
            }
        } catch {
            print("[DEBUG] NotificationManager: requestAuthorization error = \(error)")
        }

        let postSettings = await center.notificationSettings()
        // 0=notDetermined 1=denied 2=authorized 3=provisional 4=ephemeral
        print("[DEBUG] NotificationManager: post-prompt auth status = \(postSettings.authorizationStatus.rawValue), alert=\(postSettings.alertSetting.rawValue), sound=\(postSettings.soundSetting.rawValue)")
    }

    func startListening(currentUid: String) {
        self.currentUid = currentUid
        print("[DEBUG] NotificationManager.startListening uid=\(currentUid)")
        Task {
            await refreshSubscriptions()
            await primeCache()
            print("[DEBUG] NotificationManager: primed cache with \(self.planCache.count) plans, \(self.subscribedRestaurantIds.count) subs")
        }
        stopListening()

        planInsertTask = DatabaseService.shared.listenToAllPlanInserts { [weak self] plan in
            print("[DEBUG] NotificationManager: plan INSERT received id=\(plan.id) creator=\(plan.creatorId) restaurant=\(plan.restaurantId)")
            self?.handleNewPlan(plan)
            self?.planCache[plan.id] = plan
        }
        planUpdateTask = DatabaseService.shared.listenToAllPlanUpdates { [weak self] plan in
            print("[DEBUG] NotificationManager: plan UPDATE received id=\(plan.id) members=\(plan.memberIds.count)/\(plan.neededPeople)")
            self?.handlePlanUpdate(plan)
        }
        print("[DEBUG] NotificationManager: subscribed to plan inserts + updates")
    }

    func stopListening() {
        planInsertTask?.cancel()
        planInsertTask = nil
        planUpdateTask?.cancel()
        planUpdateTask = nil
    }

    func refreshSubscriptions() async {
        guard !currentUid.isEmpty else { return }
        let subs = (try? await DatabaseService.shared.fetchSubscriptions(userId: currentUid)) ?? []
        subscribedRestaurantIds = Set(subs.map(\.restaurantId))
    }

    /// Seed the cache with the user's current active plans so we have a
    /// baseline membership snapshot to diff future updates against. Without
    /// this, the first `UPDATE` after launch would always look like "no new
    /// members" because we'd have nothing to compare against.
    private func primeCache() async {
        guard !currentUid.isEmpty else { return }
        let plans = (try? await DatabaseService.shared.fetchMyActivePlans(userId: currentUid)) ?? []
        planCache = Dictionary(uniqueKeysWithValues: plans.map { ($0.id, $0) })
    }

    // MARK: - Plan insert (new plan at a restaurant)

    private func handleNewPlan(_ plan: Plan) {
        let pref = NotificationPreference(rawValue: UserDefaults.standard.string(forKey: "notification_preference") ?? "subscribed") ?? .subscribed
        guard plan.creatorId != currentUid else {
            print("[DEBUG] NotificationManager.handleNewPlan: skipping — own plan")
            return
        }
        switch pref {
        case .off:
            print("[DEBUG] NotificationManager.handleNewPlan: skipping — preference is off")
            return
        case .subscribed:
            guard subscribedRestaurantIds.contains(plan.restaurantId) else {
                print("[DEBUG] NotificationManager.handleNewPlan: skipping — not subscribed to \(plan.restaurantId)")
                return
            }
        case .all:
            break
        }
        print("[DEBUG] NotificationManager.handleNewPlan: posting new-plan alert for \(plan.id)")
        post(
            id: "plan-\(plan.id)",
            title: AppLocalization.string("New plan at %@", plan.restaurantName),
            body:  AppLocalization.string("%@ just created a plan — %@", plan.creatorName, plan.timeDisplay)
        )
    }

    // MARK: - Plan update (member joined / raft ready)

    private func handlePlanUpdate(_ newPlan: Plan) {
        let oldPlan = planCache[newPlan.id]
        // Always update the cache, even if we're not a member, so a future
        // join still gets diffed against an accurate baseline.
        defer { planCache[newPlan.id] = newPlan }

        guard newPlan.memberIds.contains(currentUid) else {
            print("[DEBUG] NotificationManager.handlePlanUpdate: skipping \(newPlan.id) — I'm not a member")
            return
        }
        // No baseline yet — `primeCache` either hasn't finished or this plan
        // wasn't in my active list at startup. Treat this UPDATE as the
        // baseline rather than treating every existing member as "newly
        // joined" — otherwise we'd fire a burst of false alerts on launch.
        guard let oldPlan else {
            print("[DEBUG] NotificationManager.handlePlanUpdate: no baseline for \(newPlan.id) — caching as baseline only")
            return
        }

        let oldMembers = Set(oldPlan.memberIds)
        let newMembers = Set(newPlan.memberIds)
        // Anyone in the new set that wasn't there before — and isn't me.
        let added = newMembers.subtracting(oldMembers).subtracting([currentUid])

        let oldFull = oldPlan.currentPeople >= oldPlan.neededPeople
        let nowFull = newPlan.currentPeople >= newPlan.neededPeople
        let justFilled = !oldFull && nowFull

        print("[DEBUG] NotificationManager.handlePlanUpdate: \(newPlan.id) added=\(added.count) justFilled=\(justFilled)")

        for newMemberUid in added {
            let name = UserCache.shared.name(
                for: newMemberUid,
                fallback: AppLocalization.string("Someone")
            )
            post(
                id: "join-\(newPlan.id)-\(newMemberUid)",
                title: AppLocalization.string("New raft member at %@", newPlan.restaurantName),
                body:  AppLocalization.string("%@ joined the pin", name)
            )
        }

        if justFilled {
            post(
                id: "ready-\(newPlan.id)",
                title: AppLocalization.string("Your raft at %@ is ready 🎉", newPlan.restaurantName),
                body:  AppLocalization.string("Everyone's in. Time to lock in the meet-up.")
            )
        }
    }

    // MARK: - Helpers

    private func post(id: String, title: String, body: String) {
        print("[DEBUG] NotificationManager.post id=\(id) title=\"\(title)\"")
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req) { error in
            if let error {
                print("[DEBUG] NotificationManager.post FAILED id=\(id): \(error)")
            } else {
                print("[DEBUG] NotificationManager.post delivered id=\(id)")
            }
        }
    }
}

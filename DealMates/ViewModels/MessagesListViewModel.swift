import SwiftUI
import Combine

@MainActor
final class MessagesListViewModel: ObservableObject {
    @Published var items: [ConversationItem] = []
    @Published var isLoading = false

    private let service = DatabaseService.shared

    func load(currentUid: String) async {
        guard !currentUid.isEmpty else { return }
        // Only show the full-screen loading state on the first load. Subsequent
        // reloads (auto-refresh on appear, pull-to-refresh, realtime triggers)
        // leave the existing list in place — toggling `isLoading` between true
        // and false during a refresh used to swap the body shape and break
        // `.refreshable` mid-pull.
        let isFirstLoad = items.isEmpty
        if isFirstLoad { isLoading = true }

        async let dmsTask = service.fetchConversations(currentUid: currentUid)
        async let plansTask = service.fetchMyActivePlans(userId: currentUid)

        let dms = (try? await dmsTask) ?? []
        let plans = (try? await plansTask) ?? []

        let latestByPlan = (try? await service.fetchLatestMessages(planIds: plans.map(\.id))) ?? [:]

        var items: [ConversationItem] = []

        for dm in dms {
            items.append(ConversationItem(
                kind: .dm(otherUid: dm.otherUserId),
                fallbackTitle: dm.otherUserName,
                subtitle: nil,
                fallbackAvatarURL: dm.otherUserAvatarURL,
                lastMessageText: dm.lastMessage,
                lastTimestamp: dm.lastTimestamp,
                lastSenderId: dm.lastSenderId,
                lastIsSystem: false,
                lastSystemKind: nil,
                lastSystemArgs: nil
            ))
        }

        for plan in plans {
            let last = latestByPlan[plan.id]
            // Localize the subtitle at construction time — the view layer just
            // renders the already-formatted String verbatim. "%@" can't be used
            // since both args are numbers, so the entire phrase is the key.
            let subtitle = String(
                format: AppLocalization.string("Group · %lld/%lld"),
                plan.currentPeople,
                plan.neededPeople
            )
            items.append(ConversationItem(
                kind: .plan(plan: plan),
                fallbackTitle: plan.restaurantName,
                subtitle: subtitle,
                fallbackAvatarURL: plan.creatorAvatarURL,
                lastMessageText: last?.text ?? "No messages yet",
                lastTimestamp: last?.timestamp ?? .distantPast,
                lastSenderId: last?.senderId,
                lastIsSystem: last?.isSystem ?? false,
                lastSystemKind: last?.systemKind,
                lastSystemArgs: last?.systemArgs
            ))
        }

        self.items = items.sorted { $0.lastTimestamp > $1.lastTimestamp }

        // Warm the cache so live names/avatars are available for the row renderer.
        var idsToFetch: [String] = []
        for dm in dms { idsToFetch.append(dm.otherUserId) }
        for plan in plans { idsToFetch.append(plan.creatorId) }
        for last in latestByPlan.values where !last.isSystem { idsToFetch.append(last.senderId) }
        await UserCache.shared.prefetch(ids: idsToFetch)

        isLoading = false
    }
}

import SwiftUI
import Combine

@MainActor
final class MessagesListViewModel: ObservableObject {
    @Published var items: [ConversationItem] = []
    @Published var isLoading = false

    private let service = DatabaseService.shared

    func load(currentUid: String) async {
        guard !currentUid.isEmpty else { return }
        isLoading = true

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
            items.append(ConversationItem(
                kind: .plan(plan: plan),
                fallbackTitle: plan.restaurantName,
                subtitle: "Group · \(plan.currentPeople)/\(plan.neededPeople)",
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

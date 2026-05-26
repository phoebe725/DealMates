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
                kind: .dm(otherUid: dm.otherUserId, otherName: dm.otherUserName, otherAvatar: dm.otherUserAvatarURL),
                title: dm.otherUserName,
                subtitle: nil,
                avatarURL: dm.otherUserAvatarURL,
                lastMessage: dm.lastMessage,
                lastTimestamp: dm.lastTimestamp,
                lastSenderId: dm.lastSenderId
            ))
        }

        for plan in plans {
            let last = latestByPlan[plan.id]
            let preview: String
            if let m = last {
                preview = m.isSystem ? m.text : "\(m.senderName): \(m.text)"
            } else {
                preview = "No messages yet"
            }
            items.append(ConversationItem(
                kind: .plan(plan: plan),
                title: plan.restaurantName,
                subtitle: "Group · \(plan.currentPeople)/\(plan.neededPeople)",
                avatarURL: plan.creatorAvatarURL,
                lastMessage: preview,
                lastTimestamp: last?.timestamp ?? .distantPast,
                lastSenderId: last?.senderId
            ))
        }

        self.items = items.sorted { $0.lastTimestamp > $1.lastTimestamp }
        isLoading = false
    }
}

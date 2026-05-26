import Foundation
import Combine

@MainActor
final class UnreadManager: ObservableObject {
    static let shared = UnreadManager()

    @Published private(set) var totalUnread: Int = 0

    private let defaults = UserDefaults.standard
    private let service = DatabaseService.shared

    private init() {}

    private func lastSeenKey(for chatId: String) -> String { "unread.lastSeen.\(chatId)" }

    func lastSeen(for chatId: String) -> Date {
        if let t = defaults.object(forKey: lastSeenKey(for: chatId)) as? Date { return t }
        return .distantPast
    }

    func markRead(chatId: String) {
        defaults.set(Date(), forKey: lastSeenKey(for: chatId))
        Task { await refresh(currentUid: currentUidHint) }
    }

    func isUnread(chatId: String, lastActivity: Date) -> Bool {
        lastActivity > lastSeen(for: chatId)
    }

    private var currentUidHint: String = ""

    func refresh(currentUid: String) async {
        guard !currentUid.isEmpty else { return }
        currentUidHint = currentUid

        async let plansTask = service.fetchMyActivePlans(userId: currentUid)
        async let dmsTask = service.fetchConversations(currentUid: currentUid)

        let plans = (try? await plansTask) ?? []
        let dms = (try? await dmsTask) ?? []

        let latestByPlan = (try? await service.fetchLatestMessages(planIds: plans.map(\.id))) ?? [:]

        var count = 0
        for plan in plans {
            guard let msg = latestByPlan[plan.id] else { continue }
            // Don't count your own messages as unread.
            if msg.senderId == currentUid { continue }
            if msg.timestamp > lastSeen(for: "plan-\(plan.id)") {
                count += 1
            }
        }
        for dm in dms {
            if dm.lastSenderId == currentUid { continue }
            if dm.lastTimestamp > lastSeen(for: "dm-\(dm.otherUserId)") {
                count += 1
            }
        }

        totalUnread = count
    }
}

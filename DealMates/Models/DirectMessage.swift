import Foundation

struct DirectMessage: Identifiable, Codable, Equatable {
    var id: String
    var senderId: String
    var senderName: String
    var senderAvatarURL: String?
    var recipientId: String
    var recipientName: String
    var recipientAvatarURL: String?
    var text: String
    var timestamp: Date

    init(senderId: String, senderName: String, senderAvatarURL: String?,
         recipientId: String, recipientName: String, recipientAvatarURL: String?,
         text: String) {
        self.id = UUID().uuidString.lowercased()
        self.senderId = senderId
        self.senderName = senderName
        self.senderAvatarURL = senderAvatarURL
        self.recipientId = recipientId
        self.recipientName = recipientName
        self.recipientAvatarURL = recipientAvatarURL
        self.text = text
        self.timestamp = Date()
    }
}

extension DirectMessage {
    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case senderName = "sender_name"
        case senderAvatarURL = "sender_avatar_url"
        case recipientId = "recipient_id"
        case recipientName = "recipient_name"
        case recipientAvatarURL = "recipient_avatar_url"
        case text
        case timestamp
    }
}

/// Summary used in conversation list — the other user + the most recent message exchanged.
struct DMConversation: Identifiable, Hashable {
    let otherUserId: String
    let otherUserName: String
    let otherUserAvatarURL: String?
    let lastMessage: String
    let lastTimestamp: Date
    let lastSenderId: String

    var id: String { otherUserId }
}

/// Unified entry in the Messages tab — either a 1:1 DM thread or a group plan chat.
///
/// Snapshots (`fallbackTitle`, `fallbackAvatarURL`, sender names baked into `lastMessageText`)
/// are kept ONLY as fallbacks for when `UserCache` hasn't yet seen the row. The Messages list
/// view resolves the live title/avatar via the cache so historical conversations always show
/// the participant's current profile.
struct ConversationItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case dm(otherUid: String)
        case plan(plan: Plan)
    }

    let kind: Kind
    let fallbackTitle: String
    let subtitle: String?
    let fallbackAvatarURL: String?
    let lastMessageText: String
    let lastTimestamp: Date
    let lastSenderId: String?
    let lastIsSystem: Bool
    // Carried so the Messages list can render the localized template for system messages
    // (e.g. "Alice 加入了计划 🙌"), not the snapshot English `lastMessageText`.
    let lastSystemKind: String?
    let lastSystemArgs: [String]?

    var id: String {
        switch kind {
        case .dm(let uid):    return "dm-\(uid)"
        case .plan(let plan): return "plan-\(plan.id)"
        }
    }

    var chatId: String { id }

    static func == (lhs: ConversationItem, rhs: ConversationItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

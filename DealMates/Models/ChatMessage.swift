import Foundation

struct ChatMessage: Identifiable, Codable {
    var id: String
    var planId: String
    var senderId: String
    var senderName: String
    var senderAvatarURL: String?
    var text: String
    var timestamp: Date
    var isSystem: Bool

    // For system messages: a stable kind identifier + the user ids referenced by the
    // template (e.g. ["alice-uid"] for "joined", ["leaver-uid", "newOrg-uid"] for
    // "left_promoted"). Names are resolved live from `UserCache` at render time so the
    // chat reflects each user's current display name.
    var systemKind: String?
    var systemArgs: [String]?

    init(planId: String, senderId: String, senderName: String, senderAvatarURL: String? = nil,
         text: String, isSystem: Bool = false,
         systemKind: String? = nil, systemArgs: [String]? = nil) {
        self.id              = UUID().uuidString.lowercased()
        self.planId          = planId
        self.senderId        = senderId
        self.senderName      = senderName
        self.senderAvatarURL = senderAvatarURL
        self.text            = text
        self.timestamp       = Date()
        self.isSystem        = isSystem
        self.systemKind      = systemKind
        self.systemArgs      = systemArgs
    }
}

extension ChatMessage {
    enum CodingKeys: String, CodingKey {
        case id
        case planId = "plan_id"
        case senderId = "sender_id"
        case senderName = "sender_name"
        case senderAvatarURL = "sender_avatar_url"
        case text
        case timestamp
        case isSystem = "is_system"
        case systemKind = "system_kind"
        case systemArgs = "system_args"
    }
}

extension ChatMessage {
    /// User-facing text. For structured system messages (with `systemKind` + `systemArgs`),
    /// formats the localized template substituting in each arg user's current display name
    /// from `UserCache`. Legacy messages without a kind fall back to the stored `text`.
    @MainActor
    func displayText() -> String {
        guard let kind = systemKind, let args = systemArgs else { return text }
        let cache = UserCache.shared
        let names = args.map { cache.name(for: $0, fallback: NSLocalizedString("Diner", comment: "Fallback name for an unknown user")) }
        let key: String
        switch kind {
        case "joined":         key = "system.joined"
        case "left":           key = "system.left"
        case "left_promoted":  key = "system.left_promoted"
        case "removed":        key = "system.removed"
        default:               return text
        }
        let format = NSLocalizedString(key, comment: "System chat message template")
        return String(format: format, arguments: names.map { $0 as CVarArg })
    }
}

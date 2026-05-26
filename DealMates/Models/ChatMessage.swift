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

    init(planId: String, senderId: String, senderName: String, senderAvatarURL: String? = nil,
         text: String, isSystem: Bool = false) {
        self.id              = UUID().uuidString.lowercased()
        self.planId          = planId
        self.senderId        = senderId
        self.senderName      = senderName
        self.senderAvatarURL = senderAvatarURL
        self.text            = text
        self.timestamp       = Date()
        self.isSystem        = isSystem
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
    }
}

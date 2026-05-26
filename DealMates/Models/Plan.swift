import Foundation

// MARK: - Plan Model

struct Plan: Identifiable, Codable, Hashable {
    var id: String
    var restaurantId: String
    var restaurantName: String
    var creatorId: String
    var creatorName: String
    var creatorAvatarURL: String?
    var isAsap: Bool
    var scheduledAt: Date
    var neededPeople: Int
    var currentPeople: Int
    var memberIds: [String]
    var notes: String
    var expiresAt: Date
    var reportedBy: [String]

    // MARK: Computed

    var needsMorePeople: Int   { max(0, neededPeople - currentPeople) }
    var isExpired: Bool        { expiresAt < Date() }

    var timeDisplay: String {
        if isAsap { return "ASAP" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: scheduledAt)
    }

    func isMember(uid: String) -> Bool { memberIds.contains(uid) }
}

extension Plan {
    enum CodingKeys: String, CodingKey {
        case id
        case restaurantId = "restaurant_id"
        case restaurantName = "restaurant_name"
        case creatorId = "creator_id"
        case creatorName = "creator_name"
        case creatorAvatarURL = "creator_avatar_url"
        case isAsap = "is_asap"
        case scheduledAt = "scheduled_at"
        case neededPeople = "needed_people"
        case currentPeople = "current_people"
        case memberIds = "member_ids"
        case notes
        case expiresAt = "expires_at"
        case reportedBy = "reported_by"
    }
}

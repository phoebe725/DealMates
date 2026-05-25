import Foundation

// MARK: - Purpose Enum

enum PlanPurpose: String, Codable, CaseIterable {
    case discount = "discount"
    case company  = "company"
    case either   = "either"

    var label: String {
        switch self {
        case .discount: return "Group Discount"
        case .company:  return "Company"
        case .either:   return "Either"
        }
    }

    var icon: String {
        switch self {
        case .discount: return "percent"
        case .company:  return "person.2.fill"
        case .either:   return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Plan Model

struct Plan: Identifiable, Codable {
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
    var purpose: PlanPurpose
    var notes: String
    var expiresAt: Date
    var reportedBy: [String]

    // MARK: Computed

    var needsMorePeople: Int   { max(0, neededPeople - currentPeople) }
    var isExpired: Bool        { expiresAt < Date() }

    var timeDisplay: String {
        if isAsap { return "ASAP" }
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
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
        case purpose
        case notes
        case expiresAt = "expires_at"
        case reportedBy = "reported_by"
    }
}

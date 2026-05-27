import Foundation

enum PlanTimeType: String, Codable, CaseIterable, Identifiable {
    case asap, scheduled, flexible
    var id: String { rawValue }
}

enum FlexDay: String, Codable, CaseIterable, Identifiable {
    case weekday, weekend
    var id: String { rawValue }
}

enum FlexMeal: String, Codable, CaseIterable, Identifiable {
    case lunch, dinner
    var id: String { rawValue }
}

enum GenderPreference: String, Codable, CaseIterable, Identifiable {
    case any, female, male
    var id: String { rawValue }
    var label: String {
        switch self {
        case .any:    return "Open to any"
        case .female: return "Female only"
        case .male:   return "Male only"
        }
    }
    var icon: String {
        switch self {
        case .any:    return "person.2.fill"
        case .female: return "person.fill"
        case .male:   return "person.fill"
        }
    }
}

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
    var timeType: PlanTimeType
    var flexDay: FlexDay?
    var flexMeal: FlexMeal?
    var genderPreference: GenderPreference

    // MARK: Computed

    var needsMorePeople: Int   { max(0, neededPeople - currentPeople) }
    var isExpired: Bool        { expiresAt < Date() }

    var timeDisplay: String {
        switch timeType {
        case .asap:
            return NSLocalizedString("ASAP", comment: "")
        case .flexible:
            let dayKey: String = (flexDay == .weekend) ? "Weekend" : "Weekday"
            let mealKey: String = (flexMeal == .dinner) ? "Dinner" : "Lunch"
            let day = NSLocalizedString(dayKey, comment: "")
            let meal = NSLocalizedString(mealKey, comment: "")
            return "\(day) \(meal)"
        case .scheduled:
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            return f.string(from: scheduledAt)
        }
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
        case timeType = "time_type"
        case flexDay = "flex_day"
        case flexMeal = "flex_meal"
        case genderPreference = "gender_preference"
    }
}

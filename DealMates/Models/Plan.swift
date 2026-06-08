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
    var attendanceConfirmedAt: Date?
    /// Server insert time. Optional so older rows and local inserts (where the
    /// DB default fills it) still decode. Tie-breaker for plan ordering.
    var createdAt: Date?
    /// Short shareable code, e.g. PT482. Shown on plan detail so anyone
    /// can share the plan without needing a link.
    var eventCode: String?

    // MARK: Computed

    var needsMorePeople: Int   { max(0, neededPeople - currentPeople) }
    var isExpired: Bool        { expiresAt < Date() }

    var timeDisplay: String {
        switch timeType {
        case .asap:
            return AppLocalization.string("ASAP")
        case .flexible:
            let dayKey: String = (flexDay == .weekend) ? "Weekend" : "Weekday"
            let mealKey: String = (flexMeal == .dinner) ? "Dinner" : "Lunch"
            let day = AppLocalization.string(dayKey)
            let meal = AppLocalization.string(mealKey)
            return "\(day) \(meal)"
        case .scheduled:
            let f = DateFormatter()
            if let lang = UserDefaults.standard.string(forKey: "preferredLanguageCode") {
                f.locale = Locale(identifier: lang)
            }
            // Include the weekday, e.g. "Mon 8 Jun 2026, 14:14" (localized order).
            f.setLocalizedDateFormatFromTemplate("EEE d MMM yyyy jmm")
            return f.string(from: scheduledAt)
        }
    }

    func isMember(uid: String) -> Bool { memberIds.contains(uid) }

    /// Locale-aware "created" date + time, or nil if the row predates the
    /// created_at column. Shown on plan cards and the plan detail screen.
    var createdDisplay: String? {
        guard let createdAt else { return nil }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        if let lang = UserDefaults.standard.string(forKey: "preferredLanguageCode") {
            f.locale = Locale(identifier: lang)
        }
        return f.string(from: createdAt)
    }

    /// Inferred (no DB field) — true when the plan's notes or restaurant name
    /// mention a dining deal. Drives the "Deal" badge on plan cards.
    var hasDeal: Bool {
        let haystack = (notes + " " + restaurantName).lowercased()
        let keywords = ["優惠", "优惠", "买", "買", "送", "deal", "offer", "discount", "ayce", "buffet"]
        return keywords.contains { haystack.contains($0) }
    }

    /// Default list ordering. Plans with a specific meeting date/time come
    /// first, soonest at the top; plans without one (ASAP / flexible) follow,
    /// most-recently-created at the top.
    static func defaultOrder(_ a: Plan, _ b: Plan) -> Bool {
        let aTimed = a.timeType == .scheduled
        let bTimed = b.timeType == .scheduled
        if aTimed != bTimed { return aTimed }
        if aTimed { return a.scheduledAt < b.scheduledAt }
        return (a.createdAt ?? .distantPast) > (b.createdAt ?? .distantPast)
    }
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
        case attendanceConfirmedAt = "attendance_confirmed_at"
        case createdAt = "created_at"
        case eventCode = "event_code"
    }
}

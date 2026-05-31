import Foundation

enum Gender: String, Codable, CaseIterable, Identifiable {
    case female, male
    var id: String { rawValue }
    /// English source key for localization.
    var label: String {
        switch self {
        case .female: return "Female"
        case .male:   return "Male"
        }
    }
}

struct AppUser: Codable, Identifiable {
    var id: String
    var email: String
    var displayName: String
    var bio: String
    var avatarURL: String?
    var gender: Gender?
    var age: Int?
    var attendedCount: Int
    var attendanceRecordCount: Int
    var hostedCount: Int

    /// Percentage of attended vs recorded plans. nil when no plans have been confirmed yet.
    var attendanceRate: Double? {
        guard attendanceRecordCount > 0 else { return nil }
        return Double(attendedCount) / Double(attendanceRecordCount)
    }
    var isAnonymous: Bool
    var blockedUsers: [String]
    var reportedPlans: [String]
    var createdAt: Date
    var updatedAt: Date

    init(id: String, email: String, displayName: String) {
        self.id             = id
        self.email          = email
        self.displayName    = displayName
        self.bio            = ""
        self.avatarURL      = nil
        self.gender         = nil
        self.age            = nil
        self.attendedCount  = 0
        self.attendanceRecordCount = 0
        self.hostedCount    = 0
        self.isAnonymous    = email.isEmpty
        self.blockedUsers   = []
        self.reportedPlans  = []
        self.createdAt      = Date()
        self.updatedAt      = Date()
    }
}

extension AppUser {
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case bio
        case avatarURL = "avatar_url"
        case gender
        case age
        case attendedCount = "attended_count"
        case attendanceRecordCount = "attendance_record_count"
        case hostedCount = "hosted_count"
        case isAnonymous = "is_anonymous"
        case blockedUsers = "blocked_users"
        case reportedPlans = "reported_plans"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Resilient custom decoder. The `users` table's `email` column is
    /// nullable, and `attended_count` / `hosted_count` / etc. were added by
    /// later migrations — old rows or partial realtime payloads can ship with
    /// any of these missing. Defaulting them here keeps the decode (and
    /// therefore the realtime listener) from silently failing on edge cases.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                    = try c.decode(String.self, forKey: .id)
        email                 = (try? c.decodeIfPresent(String.self, forKey: .email)) ?? ""
        displayName           = try c.decode(String.self, forKey: .displayName)
        bio                   = (try? c.decodeIfPresent(String.self, forKey: .bio)) ?? ""
        avatarURL             = try? c.decodeIfPresent(String.self, forKey: .avatarURL)
        gender                = try? c.decodeIfPresent(Gender.self, forKey: .gender)
        age                   = try? c.decodeIfPresent(Int.self, forKey: .age)
        attendedCount         = (try? c.decodeIfPresent(Int.self, forKey: .attendedCount)) ?? 0
        attendanceRecordCount = (try? c.decodeIfPresent(Int.self, forKey: .attendanceRecordCount)) ?? 0
        hostedCount           = (try? c.decodeIfPresent(Int.self, forKey: .hostedCount)) ?? 0
        isAnonymous           = (try? c.decodeIfPresent(Bool.self, forKey: .isAnonymous)) ?? false
        blockedUsers          = (try? c.decodeIfPresent([String].self, forKey: .blockedUsers)) ?? []
        reportedPlans         = (try? c.decodeIfPresent([String].self, forKey: .reportedPlans)) ?? []
        createdAt             = (try? c.decodeIfPresent(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt             = (try? c.decodeIfPresent(Date.self, forKey: .updatedAt)) ?? Date()
    }
}

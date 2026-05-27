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
        case isAnonymous = "is_anonymous"
        case blockedUsers = "blocked_users"
        case reportedPlans = "reported_plans"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

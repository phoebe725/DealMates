import Foundation

struct Poll: Identifiable, Codable, Hashable {
    var id: String
    var planId: String
    var creatorId: String
    var creatorName: String
    var question: String
    var options: [String]
    var createdAt: Date

    init(planId: String, creatorId: String, creatorName: String, question: String, options: [String]) {
        self.id = UUID().uuidString.lowercased()
        self.planId = planId
        self.creatorId = creatorId
        self.creatorName = creatorName
        self.question = question
        self.options = options
        self.createdAt = Date()
    }
}

extension Poll {
    enum CodingKeys: String, CodingKey {
        case id
        case planId = "plan_id"
        case creatorId = "creator_id"
        case creatorName = "creator_name"
        case question
        case options
        case createdAt = "created_at"
    }
}

struct PollVote: Codable, Hashable {
    var pollId: String
    var userId: String
    var optionIndex: Int

    enum CodingKeys: String, CodingKey {
        case pollId = "poll_id"
        case userId = "user_id"
        case optionIndex = "option_index"
    }
}

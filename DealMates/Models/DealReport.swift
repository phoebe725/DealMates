import Foundation

/// A user-submitted price/deal correction (deal_reports table). Stored separately
/// from official offers; reviewed (approved/rejected) out of band — it never
/// overwrites curated data directly.
struct DealReport: Identifiable, Codable, Hashable {
    var id: String
    var restaurantId: String
    var offerId: String?
    var reporterId: String?
    var reporterName: String?
    var reportedPrice: Double?
    var note: String?
    var status: String          // pending | approved | rejected
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case restaurantId  = "restaurant_id"
        case offerId        = "offer_id"
        case reporterId     = "reporter_id"
        case reporterName   = "reporter_name"
        case reportedPrice  = "reported_price"
        case note
        case status
        case createdAt      = "created_at"
    }
}

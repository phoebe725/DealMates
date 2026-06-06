import Foundation

/// A deal extracted by the weekly refresh job, awaiting founder review in the
/// admin queue. `source` is a short label only ('website' / 'timeout' /
/// 'tastecard') — never a URL — and is shown to the founder for context.
struct PendingDeal: Identifiable, Codable, Hashable {
    var id: String
    var restaurantId: String?
    var title: String
    var detail: String
    var source: String?
    var confidence: String?
    var status: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case restaurantId = "restaurant_id"
        case title
        case detail
        case source
        case confidence
        case status
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(String.self, forKey: .id)
        restaurantId = try? c.decodeIfPresent(String.self, forKey: .restaurantId)
        title        = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? ""
        detail       = (try? c.decodeIfPresent(String.self, forKey: .detail)) ?? ""
        source       = try? c.decodeIfPresent(String.self, forKey: .source)
        confidence   = try? c.decodeIfPresent(String.self, forKey: .confidence)
        status       = (try? c.decodeIfPresent(String.self, forKey: .status)) ?? "pending"
        createdAt    = try? c.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}

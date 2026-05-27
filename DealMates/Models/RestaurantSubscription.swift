import Foundation

struct RestaurantSubscription: Codable, Hashable {
    var userId: String
    var restaurantId: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case userId       = "user_id"
        case restaurantId = "restaurant_id"
        case createdAt    = "created_at"
    }
}

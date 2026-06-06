import Foundation

/// Normalized offer (restaurant_offers table). Read in preference to the legacy
/// Restaurant.deals* JSON, which remains as a fallback.
struct RestaurantOffer: Identifiable, Codable, Hashable {
    var id: String
    var restaurantId: String
    var offerOrder: Int
    var titleEn: String?
    var titleZhHans: String?
    var titleZhHant: String?
    var descriptionEn: String?
    var descriptionZhHans: String?
    var descriptionZhHant: String?
    var offerType: String
    var category: String          // group_gated | deal | highlight
    var isGroupGated: Bool
    var isDealLike: Bool
    var minPeople: Int?
    var maxPeople: Int?
    var pricePp: Double?
    var currency: String?
    var isActive: Bool

    var displayTitle: String {
        switch AppLocale.current {
        case .zhHans: return titleZhHans ?? titleEn ?? ""
        case .zhHant: return titleZhHant ?? titleEn ?? ""
        case .other:  return titleEn ?? ""
        }
    }

    var displayDescription: String {
        switch AppLocale.current {
        case .zhHans: return descriptionZhHans ?? descriptionEn ?? ""
        case .zhHant: return descriptionZhHant ?? descriptionEn ?? ""
        case .other:  return descriptionEn ?? ""
        }
    }

    /// Language-neutral group-gate badge (👥 4+, 👥 2–4), or nil when not gated.
    var groupBadge: String? {
        guard isGroupGated, let min = minPeople else { return nil }
        if let max = maxPeople, max != min { return "👥 \(min)–\(max)" }
        if let max = maxPeople, max == min { return "👥 \(min)" }
        return "👥 \(min)+"
    }

    /// Offers that belong in the Deals experience (everything but highlights).
    static func deals(_ offers: [RestaurantOffer]) -> [RestaurantOffer] {
        offers.filter { $0.category != "highlight" }
    }

    /// The single most important offer for a card: group-gated wins, then deal.
    static func top(_ offers: [RestaurantOffer]) -> RestaurantOffer? {
        offers.first { $0.category == "group_gated" } ?? offers.first { $0.category == "deal" }
    }

    /// Build an offer-shaped value from a legacy Deal for fallback rendering.
    static func fromDeal(_ d: Deal, restaurantId: String, index: Int) -> RestaurantOffer {
        RestaurantOffer(
            id: "legacy-\(restaurantId)-\(index)", restaurantId: restaurantId, offerOrder: index,
            titleEn: d.title, titleZhHans: nil, titleZhHant: nil,
            descriptionEn: d.detail, descriptionZhHans: nil, descriptionZhHant: nil,
            offerType: "other", category: "deal", isGroupGated: false, isDealLike: true,
            minPeople: nil, maxPeople: nil, pricePp: nil, currency: "GBP", isActive: true
        )
    }
}

extension RestaurantOffer {
    enum CodingKeys: String, CodingKey {
        case id
        case restaurantId = "restaurant_id"
        case offerOrder = "offer_order"
        case titleEn = "title_en"
        case titleZhHans = "title_zh_hans"
        case titleZhHant = "title_zh_hant"
        case descriptionEn = "description_en"
        case descriptionZhHans = "description_zh_hans"
        case descriptionZhHant = "description_zh_hant"
        case offerType = "offer_type"
        case category
        case isGroupGated = "is_group_gated"
        case isDealLike = "is_deal_like"
        case minPeople = "min_people"
        case maxPeople = "max_people"
        case pricePp = "price_pp"
        case currency
        case isActive = "is_active"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(String.self, forKey: .id)
        restaurantId     = try c.decode(String.self, forKey: .restaurantId)
        offerOrder       = (try? c.decodeIfPresent(Int.self, forKey: .offerOrder)) ?? 0
        titleEn          = try? c.decodeIfPresent(String.self, forKey: .titleEn)
        titleZhHans      = try? c.decodeIfPresent(String.self, forKey: .titleZhHans)
        titleZhHant      = try? c.decodeIfPresent(String.self, forKey: .titleZhHant)
        descriptionEn    = try? c.decodeIfPresent(String.self, forKey: .descriptionEn)
        descriptionZhHans = try? c.decodeIfPresent(String.self, forKey: .descriptionZhHans)
        descriptionZhHant = try? c.decodeIfPresent(String.self, forKey: .descriptionZhHant)
        offerType        = (try? c.decodeIfPresent(String.self, forKey: .offerType)) ?? "other"
        category         = (try? c.decodeIfPresent(String.self, forKey: .category)) ?? "deal"
        isGroupGated     = (try? c.decodeIfPresent(Bool.self, forKey: .isGroupGated)) ?? false
        isDealLike       = (try? c.decodeIfPresent(Bool.self, forKey: .isDealLike)) ?? true
        minPeople        = try? c.decodeIfPresent(Int.self, forKey: .minPeople)
        maxPeople        = try? c.decodeIfPresent(Int.self, forKey: .maxPeople)
        pricePp          = try? c.decodeIfPresent(Double.self, forKey: .pricePp)
        currency         = try? c.decodeIfPresent(String.self, forKey: .currency)
        isActive         = (try? c.decodeIfPresent(Bool.self, forKey: .isActive)) ?? true
    }
}

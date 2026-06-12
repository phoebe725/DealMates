import Foundation

/// Normalized offer (restaurant_offers table) — the source of truth for promos.
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
    /// Price verification (mirrors web). Read-only — set via curation / admin.
    var verified: Bool
    var priceConfidence: String     // official | user_verified | review_only | unverified
    var lastVerifiedAt: Date?
    var sourceNote: String?

    enum PriceConfidenceTone { case verified, reference, unconfirmed }

    /// Localized badge key + tone for the price-confidence chip.
    /// official/user_verified → 已確認, review_only → 參考價格, else → 待確認.
    var priceConfidenceBadge: (key: String, tone: PriceConfidenceTone) {
        switch priceConfidence {
        case "official", "user_verified": return ("Verified", .verified)
        case "review_only":               return ("Reference price", .reference)
        default:                          return ("Unconfirmed", .unconfirmed)
        }
    }

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

    /// Description split into its distinct terms. The curated data uses " · " as
    /// the separator between conditions (e.g. "£32.80pp for 2+ · £45 solo · 20%
    /// off 12–17"); a single-clause description returns one element.
    var descriptionTerms: [String] {
        displayDescription
            .split(separator: "·")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
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

    // MARK: - Value-oriented display layer (mirrors web/src/lib/dealDisplay.ts)

    /// Deal sub-kind, used for filters + card priority. English text is the signal.
    var dealKind: String {
        if category == "group_gated" { return "group" }
        let s = ((titleEn ?? "") + " " + (descriptionEn ?? "")).lowercased()
        if s.contains("student") { return "student" }
        if s.contains("member") { return "member" }
        for k in ["all-you-can-eat", "all you can eat", "ayce", "buffet", "unlimited", "yum cha", "steam pot", "malatang"]
            where s.contains(k) { return "ayce" }
        for k in ["%", " off", "discount", "tastecard", "first table", "save"]
            where s.contains(k) { return "discount" }
        if s.contains("lunch") { return "lunch" }
        return "other"
    }

    /// Percentage in the offer text, e.g. "20% off" → 20.
    private var percent: Int? {
        let s = (titleEn ?? "") + " " + (descriptionEn ?? "")
        guard let r = s.range(of: "\\d{1,2}\\s*%", options: .regularExpression) else { return nil }
        return Int(s[r].filter(\.isNumber))
    }

    private static func money(_ v: Double) -> String { String(format: "%g", v) }

    struct Label { let emoji: String; let text: String }

    /// Short, value-oriented, localized label for a card or deal heading.
    var shortLabel: Label {
        func L(_ key: String, _ args: CVarArg...) -> String {
            args.isEmpty ? AppLocalization.string(key) : String(format: AppLocalization.string(key), arguments: args)
        }
        switch dealKind {
        case "group":
            if offerType == "buy_x_get_y", let m = minPeople { return Label(emoji: "👥", text: L("Buy %lld get %lld free", m, 1)) }
            if let pp = pricePp { return Label(emoji: "👥", text: L("AYCE from £%@", Self.money(pp))) }
            if offerType == "group_set_menu" { return Label(emoji: "👥", text: L("Group set menu")) }
            if let p = percent { return Label(emoji: "👥", text: L("Group deal: save %lld%", p)) }
            return Label(emoji: "👥", text: L("Group deal"))
        case "ayce":
            return pricePp != nil ? Label(emoji: "🍽", text: L("AYCE from £%@", Self.money(pricePp!))) : Label(emoji: "🍽", text: L("All you can eat"))
        case "discount":
            return percent != nil ? Label(emoji: "💸", text: L("Save %lld%", percent!)) : Label(emoji: "💸", text: L("Special offer"))
        case "student": return Label(emoji: "🎓", text: L("Student deal"))
        case "member":  return Label(emoji: "💳", text: L("Member discount"))
        case "lunch":   return Label(emoji: "🍜", text: L("Lunch set"))
        default:        return Label(emoji: "🔥", text: displayTitle)
        }
    }

    private static let priority = ["group": 0, "ayce": 1, "discount": 2, "student": 3, "member": 4, "lunch": 5, "other": 6]

    /// The strongest offer to feature on a card (deals only), by priority.
    static func best(_ offers: [RestaurantOffer]) -> RestaurantOffer? {
        deals(offers).min { (priority[$0.dealKind] ?? 9) < (priority[$1.dealKind] ?? 9) }
    }

    /// Does this offer set satisfy a deal filter (all/group/ayce/discount/student/member)?
    static func matchesFilter(_ offers: [RestaurantOffer], _ f: String) -> Bool {
        let d = deals(offers)
        if d.isEmpty { return false }
        if f == "all" { return true }
        return d.contains { $0.dealKind == f }
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
        case verified
        case priceConfidence = "price_confidence"
        case lastVerifiedAt = "last_verified_at"
        case sourceNote = "source_note"
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
        verified         = (try? c.decodeIfPresent(Bool.self, forKey: .verified)) ?? false
        priceConfidence  = (try? c.decodeIfPresent(String.self, forKey: .priceConfidence)) ?? "unverified"
        lastVerifiedAt   = try? c.decodeIfPresent(Date.self, forKey: .lastVerifiedAt)
        sourceNote       = try? c.decodeIfPresent(String.self, forKey: .sourceNote)
    }
}

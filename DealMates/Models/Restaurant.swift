import Foundation

struct Restaurant: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var cuisine: String
    var address: String
    var imageUrl: String?
    var latitude: Double?
    var longitude: Double?
    var nameZhHans: String?
    var nameZhHant: String?
    var cuisineZhHans: String?
    var cuisineZhHant: String?
    // Discover/Deals extensions (added by the 20260601 migration). Optional /
    // defaulted so existing call sites and decodes keep working unchanged.
    var isFeatured: Bool
    /// Whether the restaurant offers an all-you-can-eat / buffet menu.
    /// Source of truth for the "AYCE / Buffet" filter (the `is_buffet` column).
    var isBuffet: Bool
    /// "cover" (default, food photos) or "contain" (logos shown on image_bg).
    var imageFit: String
    var imageBg: String?
    var lastDealsVerifiedAt: Date?
    var planCount: Int
    /// Price tier 1 = £, 2 = ££, 3 = £££. nil/absent is treated as ££.
    var priceLevel: Int?

    init(id: String, name: String, cuisine: String, address: String, imageUrl: String? = nil, latitude: Double? = nil, longitude: Double? = nil, nameZhHans: String? = nil, nameZhHant: String? = nil, cuisineZhHans: String? = nil, cuisineZhHant: String? = nil, isFeatured: Bool = false, isBuffet: Bool = false, imageFit: String = "cover", imageBg: String? = nil, lastDealsVerifiedAt: Date? = nil, planCount: Int = 0) {
        self.id = id
        self.name = name
        self.cuisine = cuisine
        self.address = address
        self.imageUrl = imageUrl
        self.latitude = latitude
        self.longitude = longitude
        self.nameZhHans = nameZhHans
        self.nameZhHant = nameZhHant
        self.cuisineZhHans = cuisineZhHans
        self.cuisineZhHant = cuisineZhHant
        self.isFeatured = isFeatured
        self.isBuffet = isBuffet
        self.imageFit = imageFit
        self.imageBg = imageBg
        self.lastDealsVerifiedAt = lastDealsVerifiedAt
        self.planCount = planCount
        self.priceLevel = nil
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(String.self, forKey: .id)
        name      = try c.decode(String.self, forKey: .name)
        cuisine   = try c.decode(String.self, forKey: .cuisine)
        address   = try c.decode(String.self, forKey: .address)
        imageUrl  = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        latitude  = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        nameZhHans    = try c.decodeIfPresent(String.self, forKey: .nameZhHans)
        nameZhHant    = try c.decodeIfPresent(String.self, forKey: .nameZhHant)
        cuisineZhHans = try c.decodeIfPresent(String.self, forKey: .cuisineZhHans)
        cuisineZhHant = try c.decodeIfPresent(String.self, forKey: .cuisineZhHant)
        isFeatured          = (try? c.decodeIfPresent(Bool.self, forKey: .isFeatured)) ?? false
        isBuffet            = (try? c.decodeIfPresent(Bool.self, forKey: .isBuffet)) ?? false
        imageFit            = (try? c.decodeIfPresent(String.self, forKey: .imageFit)) ?? "cover"
        imageBg             = try? c.decodeIfPresent(String.self, forKey: .imageBg)
        lastDealsVerifiedAt = try? c.decodeIfPresent(Date.self, forKey: .lastDealsVerifiedAt)
        planCount           = (try? c.decodeIfPresent(Int.self, forKey: .planCount)) ?? 0
        priceLevel          = try? c.decodeIfPresent(Int.self, forKey: .priceLevel)
    }

    /// Was the restaurant's deal info verified within the last 14 days? Featured
    /// eligibility also requires at least one deal offer — see
    /// `RestaurantViewModel.isFeaturedEligible(_:)`, which has the offer data.
    var dealsRecentlyVerified: Bool {
        guard let verified = lastDealsVerifiedAt else { return false }
        return verified > Date().addingTimeInterval(-14 * 24 * 60 * 60)
    }
}

extension Restaurant {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case cuisine
        case address
        case imageUrl = "image_url"
        case latitude
        case longitude
        case nameZhHans = "name_zh_hans"
        case nameZhHant = "name_zh_hant"
        case cuisineZhHans = "cuisine_zh_hans"
        case cuisineZhHant = "cuisine_zh_hant"
        case isFeatured = "is_featured"
        case isBuffet = "is_buffet"
        case imageFit = "image_fit"
        case imageBg = "image_bg"
        case lastDealsVerifiedAt = "last_deals_verified_at"
        case planCount = "plan_count"
        case priceLevel = "price_level"
    }

    /// £ / ££ / £££ from the price level (nil → ££).
    var priceTier: String {
        switch priceLevel ?? 2 {
        case 1:  return "£"
        case 3:  return "£££"
        default: return "££"
        }
    }

    /// Returns name in the user's preferred app language (zh-Hans / zh-Hant) if available, else original.
    var displayName: String {
        switch AppLocale.current {
        case .zhHans: return nameZhHans ?? name
        case .zhHant: return nameZhHant ?? name
        case .other:  return name
        }
    }

    var displayCuisine: String {
        switch AppLocale.current {
        case .zhHans: return cuisineZhHans ?? cuisine
        case .zhHant: return cuisineZhHant ?? cuisine
        case .other:  return cuisine
        }
    }
}

enum AppLocale {
    case zhHans
    case zhHant
    case other

    static var current: AppLocale {
        // Honour the in-app language picker (SettingsView writes this to UserDefaults via
        // @AppStorage). Falling back to the OS preferred localization preserves the right
        // behaviour on first launch before the user has picked anything.
        let lang = UserDefaults.standard.string(forKey: "preferredLanguageCode")
            ?? Bundle.main.preferredLocalizations.first
            ?? "en"
        if lang.hasPrefix("zh-Hans") || lang.hasPrefix("zh_Hans") || lang == "zh-CN" { return .zhHans }
        if lang.hasPrefix("zh-Hant") || lang.hasPrefix("zh_Hant") || lang == "zh-TW" || lang == "zh-HK" { return .zhHant }
        return .other
    }

    /// Map a cuisine string (English DB value) to its localized label for menus / labels.
    static func localizedCuisine(_ cuisine: String) -> String {
        let key = cuisine.lowercased()
        switch current {
        case .zhHans:
            switch key {
            case "🔥 deals":         return "🔥 优惠"
            case "all cuisines":     return "全部菜系"
            case "ayce / buffet":    return "自助餐 / 任食"
            case "chinese":          return "中餐"
            case "hot pot":          return "火锅"
            case "japanese":         return "日本料理"
            case "sichuan":          return "川菜"
            case "hot pot / bbq":    return "火锅 / 烤肉"
            case "northern chinese": return "北方菜"
            case "dim sum":          return "点心"
            case "cantonese":        return "粤菜"
            case "taiwanese":        return "台湾菜"
            case "korean bbq":       return "韩式烤肉"
            case "korean":           return "韩国料理"
            case "vietnamese":       return "越南菜"
            case "thai":             return "泰国菜"
            case "indian":           return "印度菜"
            case "sri lankan":       return "斯里兰卡菜"
            case "pakistani":        return "巴基斯坦菜"
            case "italian":          return "意大利菜"
            case "steakhouse":       return "牛排馆"
            case "burgers":          return "汉堡"
            case "bubble tea":       return "珍珠奶茶"
            default:                 return cuisine
            }
        case .zhHant:
            switch key {
            case "🔥 deals":         return "🔥 優惠"
            case "all cuisines":     return "全部菜系"
            case "ayce / buffet":    return "自助餐 / 任食"
            case "chinese":          return "中餐"
            case "hot pot":          return "火鍋"
            case "japanese":         return "日本料理"
            case "sichuan":          return "川菜"
            case "hot pot / bbq":    return "火鍋 / 烤肉"
            case "northern chinese": return "北方菜"
            case "dim sum":          return "點心"
            case "cantonese":        return "粵菜"
            case "taiwanese":        return "台灣菜"
            case "korean bbq":       return "韓式烤肉"
            case "korean":           return "韓國料理"
            case "vietnamese":       return "越南菜"
            case "thai":             return "泰國菜"
            case "indian":           return "印度菜"
            case "sri lankan":       return "斯里蘭卡菜"
            case "pakistani":        return "巴基斯坦菜"
            case "italian":          return "義大利菜"
            case "steakhouse":       return "牛排館"
            case "burgers":          return "漢堡"
            case "bubble tea":       return "珍珠奶茶"
            default:                 return cuisine
            }
        case .other:
            return cuisine
        }
    }
}

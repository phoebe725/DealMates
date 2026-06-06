import Foundation

struct Deal: Codable, Hashable {
    var title: String
    var detail: String
}

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
    var deals: [Deal]
    var dealsZhHans: [Deal]?
    var dealsZhHant: [Deal]?
    // Discover/Deals extensions (added by the 20260601 migration). Optional /
    // defaulted so existing call sites and decodes keep working unchanged.
    var isFeatured: Bool
    var lastDealsVerifiedAt: Date?
    var planCount: Int
    var instagramHandle: String?
    var websiteUrl: String?

    init(id: String, name: String, cuisine: String, address: String, imageUrl: String? = nil, latitude: Double? = nil, longitude: Double? = nil, nameZhHans: String? = nil, nameZhHant: String? = nil, cuisineZhHans: String? = nil, cuisineZhHant: String? = nil, deals: [Deal] = [], dealsZhHans: [Deal]? = nil, dealsZhHant: [Deal]? = nil, isFeatured: Bool = false, lastDealsVerifiedAt: Date? = nil, planCount: Int = 0, instagramHandle: String? = nil, websiteUrl: String? = nil) {
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
        self.deals = deals
        self.dealsZhHans = dealsZhHans
        self.dealsZhHant = dealsZhHant
        self.isFeatured = isFeatured
        self.lastDealsVerifiedAt = lastDealsVerifiedAt
        self.planCount = planCount
        self.instagramHandle = instagramHandle
        self.websiteUrl = websiteUrl
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
        deals = (try? c.decodeIfPresent([Deal].self, forKey: .deals)) ?? []
        dealsZhHans = try? c.decodeIfPresent([Deal].self, forKey: .dealsZhHans)
        dealsZhHant = try? c.decodeIfPresent([Deal].self, forKey: .dealsZhHant)
        isFeatured          = (try? c.decodeIfPresent(Bool.self, forKey: .isFeatured)) ?? false
        lastDealsVerifiedAt = try? c.decodeIfPresent(Date.self, forKey: .lastDealsVerifiedAt)
        planCount           = (try? c.decodeIfPresent(Int.self, forKey: .planCount)) ?? 0
        instagramHandle     = try? c.decodeIfPresent(String.self, forKey: .instagramHandle)
        websiteUrl          = try? c.decodeIfPresent(String.self, forKey: .websiteUrl)
    }

    /// Eligible for the Discover "Featured" section: has at least one deal and
    /// those deals were verified within the last 14 days.
    var isFeaturedEligible: Bool {
        guard !deals.isEmpty, let verified = lastDealsVerifiedAt else { return false }
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
        case deals
        case dealsZhHans = "deals_zh_hans"
        case dealsZhHant = "deals_zh_hant"
        case isFeatured = "is_featured"
        case lastDealsVerifiedAt = "last_deals_verified_at"
        case planCount = "plan_count"
        case instagramHandle = "instagram_handle"
        case websiteUrl = "website_url"
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

    /// Locale-aware deals. Falls back to the English `deals` if no translated array exists.
    var displayDeals: [Deal] {
        switch AppLocale.current {
        case .zhHans: return dealsZhHans ?? deals
        case .zhHant: return dealsZhHant ?? deals
        case .other:  return deals
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

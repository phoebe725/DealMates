import SwiftUI

struct RestaurantCardView: View {
    let restaurant: Restaurant
    var offers: [RestaurantOffer] = []

    private var top: RestaurantOffer? { RestaurantOffer.best(offers) }
    private var isGroup: Bool { top?.dealKind == "group" }

    var body: some View {
        HStack(spacing: 14) {
            thumbnail
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.displayName)
                    .font(.pinBody(16, weight: .medium))
                    .foregroundStyle(Color.pinInk)
                    .lineLimit(2)
                Text(restaurant.displayCuisine)
                    .font(.pinSubtitle(13))
                    .foregroundStyle(Color.pinInkMuted)
                Text(restaurant.address)
                    .font(.pinSubtitle(12))
                    .foregroundStyle(Color.pinInkMuted)
                    .lineLimit(1)
                if let top {
                    Text(top.shortLabel.emoji + " " + top.shortLabel.text)
                        .font(.pinSubtitle(12).weight(.semibold))
                        .foregroundStyle(isGroup ? Color.pinClayDeep : Color.pinSunDeep)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)
        }
        .padding(14)
        .pinCard()
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private var thumbnail: some View {
        let url = restaurant.imageUrl.flatMap { URL(string: $0) }
        CachedAsyncImage(
            url: url,
            placeholder: { loadingPlaceholder },
            failure: { placeholderBubble }
        )
    }

    private var loadingPlaceholder: some View {
        Rectangle().fill(Color.pinFog)
    }

    private var placeholderBubble: some View {
        ZStack {
            Rectangle().fill(cuisineTint.opacity(0.25))
            Text(cuisineEmoji).font(.system(size: 26))
        }
    }

    private var cuisineEmoji: String {
        switch restaurant.cuisine.lowercased() {
        case "chinese":    return "🥘"
        case "japanese", "japanese / sushi": return "🍣"
        case "taiwanese":  return "🫖"
        case "thai":       return "🍜"
        case "sri lankan": return "🍛"
        case "malaysian":  return "🥜"
        case "pan-asian":  return "🥢"
        case "hot pot", "hot pot / bbq": return "🍲"
        case "sichuan":    return "🌶️"
        default:           return "🍽️"
        }
    }

    private var cuisineTint: Color {
        switch restaurant.cuisine.lowercased() {
        case "chinese", "sichuan":  return .pinClay
        case "japanese", "japanese / sushi": return .pinLavender
        case "taiwanese", "thai":   return .pinSage
        case "hot pot", "hot pot / bbq": return .pinClay
        default:                    return .pinSage
        }
    }
}

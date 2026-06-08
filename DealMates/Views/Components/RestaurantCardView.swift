import SwiftUI

/// Discover restaurant card — mirrors web/src/screens/Discover.tsx `RestaurantCard`:
/// a full-width photo on top, with name → cuisine → strongest deal label below.
struct RestaurantCardView: View {
    let restaurant: Restaurant
    var offers: [RestaurantOffer] = []

    private var deals: [RestaurantOffer] { RestaurantOffer.deals(offers) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            image
                .frame(maxWidth: .infinity)
                .frame(height: 128)
                .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.displayName)
                    .font(.pinBody(16, weight: .medium))
                    .foregroundStyle(Color.pinInk)
                    .lineLimit(2)
                (Text(restaurant.displayCuisine).foregroundStyle(Color.pinInkMuted)
                 + Text(" · " + restaurant.priceTier).foregroundStyle(Color.pinClayDeep))
                    .font(.pinSubtitle(13))
                if !deals.isEmpty {
                    // Every deal on one row, each in a tinted pill; swipe to see more.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(deals) { dealPill($0) }
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
        .background(Color.pinShell)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.pinInk.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private func dealPill(_ offer: RestaurantOffer) -> some View {
        let group = offer.dealKind == "group"
        return Text(offer.shortLabel.emoji + " " + offer.shortLabel.text)
            .font(.pinSubtitle(12).weight(.semibold))
            .foregroundStyle(group ? Color.pinClayDeep : Color.pinSunDeep)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill((group ? Color.pinClay : Color.pinSun).opacity(0.16)))
    }

    // MARK: - Image

    @ViewBuilder
    private var image: some View {
        let url = restaurant.imageUrl.flatMap { URL(string: $0) }
        if restaurant.imageFit == "contain" {
            // Logo: contain on the brand background so it isn't cropped.
            CachedAsyncImage(url: url, contentMode: .fit, placeholder: { loadingPlaceholder }, failure: { placeholderBubble })
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: restaurant.imageBg ?? "FFFFFF"))
        } else {
            CachedAsyncImage(url: url, placeholder: { loadingPlaceholder }, failure: { placeholderBubble })
        }
    }

    private var loadingPlaceholder: some View {
        Rectangle().fill(Color.pinFog)
    }

    private var placeholderBubble: some View {
        ZStack {
            Rectangle().fill(cuisineTint.opacity(0.25))
            Text(cuisineEmoji).font(.system(size: 34))
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

import SwiftUI

struct RestaurantCardView: View {
    let restaurant: Restaurant

    var body: some View {
        HStack(spacing: 14) {
            thumbnail
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(restaurant.displayCuisine)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(restaurant.address)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Helpers

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
        Rectangle().fill(Color(.tertiarySystemFill))
    }

    private var placeholderBubble: some View {
        ZStack {
            Rectangle().fill(cuisineGradient)
            Text(cuisineEmoji).font(.title2)
        }
    }

    private var cuisineEmoji: String {
        switch restaurant.cuisine.lowercased() {
        case "chinese":    return "🥘"
        case "japanese":   return "🍣"
        case "taiwanese":  return "🫖"
        case "thai":       return "🍜"
        case "sri lankan": return "🍛"
        case "malaysian":  return "🥜"
        case "pan-asian":  return "🥢"
        default:           return "🍽️"
        }
    }

    private var cuisineGradient: LinearGradient {
        let color: Color = {
            switch restaurant.cuisine.lowercased() {
            case "chinese":    return .red
            case "japanese":   return .pink
            case "taiwanese":  return .teal
            case "thai":       return .green
            case "sri lankan": return .orange
            case "malaysian":  return .yellow
            case "pan-asian":  return .purple
            default:           return .indigo
            }
        }()
        return LinearGradient(
            colors: [color.opacity(0.25), color.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

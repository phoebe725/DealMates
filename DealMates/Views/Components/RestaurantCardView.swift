import SwiftUI

struct RestaurantCardView: View {
    let restaurant: Restaurant

    var body: some View {
        HStack(spacing: 14) {
            // Icon / placeholder image
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cuisineGradient)
                    .frame(width: 56, height: 56)
                Text(cuisineEmoji)
                    .font(.title2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(restaurant.cuisine)
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

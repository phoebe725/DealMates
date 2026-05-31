import SwiftUI

/// Shared header used by both `UserProfileView` (someone else's profile) and
/// the user's own `ProfileView`. The user sees the same header others see; the
/// owner-only credit numbers live in their own section below.
struct ProfileHeaderView: View {
    let user: AppUser
    var avatarSize: CGFloat = 72
    var avatarFontSize: CGFloat = 32

    var body: some View {
        HStack(spacing: 16) {
            AvatarImage(
                urlString: user.avatarURL,
                name: user.displayName,
                size: avatarSize,
                fontSize: avatarFontSize
            )
            VStack(alignment: .leading, spacing: 8) {
                Text(user.displayName)
                    .font(.pinBody(20, weight: .medium))
                    .foregroundStyle(Color.pinInk)
                HStack(spacing: 8) {
                    if let gender = user.gender {
                        // Pass the English source key — PinChip's LocalizedStringKey
                        // does the catalog lookup. Pre-translating via NSLocalizedString
                        // hands the chip a runtime String which doesn't compile against
                        // a LocalizedStringKey parameter.
                        PinChip(
                            text: LocalizedStringKey(gender.label),
                            systemImage: "person.crop.circle.fill",
                            tint: .pinLavenderDeep
                        )
                    }
                    if let age = user.age {
                        PinChip(
                            text: "Age \(age)",
                            systemImage: "birthday.cake.fill",
                            tint: .pinClay
                        )
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

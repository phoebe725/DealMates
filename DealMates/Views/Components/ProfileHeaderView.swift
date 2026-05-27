import SwiftUI

/// Shared header used by both `UserProfileView` (when looking at someone else) and the user's
/// own `ProfileView`. The user sees the same layout others see when tapping their avatar — only
/// the owner-only credit score lives elsewhere in `ProfileView`.
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
            VStack(alignment: .leading, spacing: 6) {
                Text(user.displayName)
                    .font(.title3.bold())
                HStack(spacing: 8) {
                    if let gender = user.gender {
                        chip(
                            systemImage: "person.crop.circle.fill",
                            iconColor: .pink,
                            text: Text(LocalizedStringKey(gender.label))
                        )
                    }
                    if let age = user.age {
                        chip(
                            systemImage: "birthday.cake.fill",
                            iconColor: .orange,
                            text: Text("Age \(age)")
                        )
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func chip(systemImage: String, iconColor: Color, text: Text) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption2)
                .foregroundColor(iconColor)
            text
                .font(.caption.bold())
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.tertiarySystemFill))
        .clipShape(Capsule())
    }
}

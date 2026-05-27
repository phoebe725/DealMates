import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    let isCurrentUser: Bool
    var onAvatarTap: ((String) -> Void)? = nil

    @ObservedObject private var cache = UserCache.shared

    private var isSystem: Bool { message.isSystem }

    private var liveName: String {
        cache.name(for: message.senderId, fallback: message.senderName)
    }

    var body: some View {
        if isSystem {
            systemBubble
        } else {
            userBubble
        }
    }

    // MARK: - System message

    private var systemBubble: some View {
        HStack {
            Spacer()
            // Render the localized template for structured system messages; legacy rows fall
            // back to the stored English text (handled inside `displayText()`).
            Text(message.displayText())
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(Color(.tertiarySystemFill))
                .clipShape(Capsule())
            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - User message

    private var userBubble: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isCurrentUser {
                Spacer(minLength: 60)
            } else {
                Button {
                    onAvatarTap?(message.senderId)
                } label: {
                    LiveAvatar(
                        userId: message.senderId,
                        size: 28,
                        fontSize: 12,
                        fallbackName: message.senderName,
                        fallbackAvatarURL: message.senderAvatarURL
                    )
                }
                .buttonStyle(.plain)
                .disabled(onAvatarTap == nil || message.senderId == "system")
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 2) {
                if !isCurrentUser {
                    Text(liveName)
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }

                Text(message.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isCurrentUser ? Color.orange : Color(.systemGray5))
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }

            if isCurrentUser {
                LiveAvatar(
                    userId: message.senderId,
                    size: 28,
                    fontSize: 12,
                    fallbackName: message.senderName,
                    fallbackAvatarURL: message.senderAvatarURL
                )
            } else {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}

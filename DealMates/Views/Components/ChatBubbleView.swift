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

    // MARK: - System

    private var systemBubble: some View {
        HStack {
            Spacer()
            Text(message.displayText())
                .font(.pinSubtitle(12))
                .foregroundStyle(Color.pinInkMuted)
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(
                    Capsule(style: .continuous).fill(Color.pinShell)
                )
            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - User

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
                        .font(.pinBody(11, weight: .medium))
                        .foregroundStyle(Color.pinInkMuted)
                        .padding(.horizontal, 4)
                }

                Text(message.text)
                    .font(.pinBody(14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isCurrentUser ? Color.pinClay : Color.pinShell)
                    )
                    .foregroundStyle(isCurrentUser ? Color.pinCream : Color.pinInk)

                Text(message.timestamp, style: .time)
                    .font(.pinSubtitle(10))
                    .foregroundStyle(Color.pinInkMuted)
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

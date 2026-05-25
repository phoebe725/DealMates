import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    let isCurrentUser: Bool

    private var isSystem: Bool { message.isSystem }

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
            Text(message.text)
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
            if isCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 2) {
                if !isCurrentUser {
                    Text(message.senderName)
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.clear)
                    )

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }

            if !isCurrentUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}

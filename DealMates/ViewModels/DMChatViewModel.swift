import SwiftUI
import Combine

@MainActor
final class DMChatViewModel: ObservableObject {
    @Published var messages: [DirectMessage] = []
    @Published var draftText = ""

    let currentUid: String
    let otherUid: String

    private var listenerTask: Task<Void, Never>?
    private let service = DatabaseService.shared

    init(currentUid: String, otherUid: String) {
        self.currentUid = currentUid
        self.otherUid = otherUid
    }

    deinit { listenerTask?.cancel() }

    func startListening() {
        // Cancel any prior listener so re-entering the view doesn't open
        // duplicate realtime channels for the same conversation.
        listenerTask?.cancel()
        // Auto-refresh-on-appear: every landing re-fetches DM history so a
        // message sent from another device appears immediately on return.
        Task {
            await UserCache.shared.ensure(id: otherUid)
            await fetchHistory()
        }

        listenerTask = service.listenToDirectMessages(currentUid: currentUid, otherUid: otherUid) { [weak self] msg in
            guard let self else { return }
            if !self.messages.contains(where: { $0.id == msg.id }) {
                self.messages.append(msg)
            }
        }
    }

    func stopListening() {
        listenerTask?.cancel()
        listenerTask = nil
    }

    func refresh() async { await fetchHistory() }

    /// Sends a DM. Sender / recipient name + avatar snapshots are pulled live from
    /// `UserCache` so the row reflects current profiles (views will still re-resolve
    /// at render time via the cache, but we keep the snapshot columns populated for
    /// backwards-compatibility with old clients).
    func send() {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draftText = ""

        let cache = UserCache.shared
        let sender = cache.user(for: currentUid)
        let recipient = cache.user(for: otherUid)

        let msg = DirectMessage(
            senderId: currentUid,
            senderName: sender?.displayName ?? "",
            senderAvatarURL: sender?.avatarURL,
            recipientId: otherUid,
            recipientName: recipient?.displayName ?? "",
            recipientAvatarURL: recipient?.avatarURL,
            text: text
        )
        if !messages.contains(where: { $0.id == msg.id }) {
            messages.append(msg)
        }
        Task { try? await service.sendDirectMessage(msg) }
    }

    private func fetchHistory() async {
        guard let msgs = try? await service.fetchDirectMessages(currentUid: currentUid, otherUid: otherUid) else { return }
        messages = msgs
    }
}

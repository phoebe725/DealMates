import SwiftUI
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var draftText = ""

    let planId: String
    private var listenerTask: Task<Void, Never>?
    private let service = DatabaseService.shared

    init(planId: String) {
        self.planId = planId
    }

    deinit { listenerTask?.cancel() }

    // MARK: - Listener

    func startListening() {
        // Re-entering the view via NavigationStack fires `.onAppear` again
        // and would open a duplicate channel — cancel the old one first.
        listenerTask?.cancel()
        // Auto-refresh-on-appear: every landing on this view re-fetches the
        // chat history, so messages sent from another device land immediately.
        Task { await fetchHistory() }

        listenerTask = service.listenToMessages(planId: planId) { [weak self] msg in
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

    // MARK: - Actions

    func refresh() async {
        await fetchHistory()
    }

    /// Sends a chat message. The sender's name/avatar are looked up live from `UserCache`,
    /// so the row written to `messages` carries the user's current profile snapshot. Readers
    /// resolve through the cache anyway, but the snapshot keeps old clients consistent.
    func send(senderId: String) {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draftText = ""
        let sender = UserCache.shared.user(for: senderId)
        let msg = ChatMessage(
            planId: planId,
            senderId: senderId,
            senderName: sender?.displayName ?? "",
            senderAvatarURL: sender?.avatarURL,
            text: text
        )
        if !messages.contains(where: { $0.id == msg.id }) {
            messages.append(msg)
        }
        Task { try? await service.sendMessage(msg) }
    }

    // MARK: - Private

    private func fetchHistory() async {
        guard let msgs = try? await service.fetchMessages(planId: planId) else { return }
        messages = msgs
    }
}

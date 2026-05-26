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

    func send(senderId: String, senderName: String, senderAvatarURL: String? = nil) {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draftText = ""
        let msg = ChatMessage(planId: planId, senderId: senderId,
                              senderName: senderName, senderAvatarURL: senderAvatarURL, text: text)
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

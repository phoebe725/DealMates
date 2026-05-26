import SwiftUI
import Combine

@MainActor
final class DMChatViewModel: ObservableObject {
    @Published var messages: [DirectMessage] = []
    @Published var draftText = ""

    let currentUid: String
    let otherUid: String
    let otherName: String
    let otherAvatarURL: String?

    private var listenerTask: Task<Void, Never>?
    private let service = DatabaseService.shared

    init(currentUid: String, otherUid: String, otherName: String, otherAvatarURL: String?) {
        self.currentUid = currentUid
        self.otherUid = otherUid
        self.otherName = otherName
        self.otherAvatarURL = otherAvatarURL
    }

    deinit { listenerTask?.cancel() }

    func startListening() {
        Task { await fetchHistory() }

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

    func send(senderName: String, senderAvatarURL: String?) {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draftText = ""
        let msg = DirectMessage(
            senderId: currentUid,
            senderName: senderName,
            senderAvatarURL: senderAvatarURL,
            recipientId: otherUid,
            recipientName: otherName,
            recipientAvatarURL: otherAvatarURL,
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

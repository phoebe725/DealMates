import SwiftUI

struct DMChatView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var vm: DMChatViewModel

    init(currentUid: String, otherUid: String, otherName: String, otherAvatarURL: String?) {
        _vm = StateObject(wrappedValue: DMChatViewModel(
            currentUid: currentUid,
            otherUid: otherUid,
            otherName: otherName,
            otherAvatarURL: otherAvatarURL
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            chatSection
            composer
        }
        .navigationTitle(vm.otherName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.startListening()
            UnreadManager.shared.markRead(chatId: "dm-\(vm.otherUid)")
        }
        .onDisappear {
            vm.stopListening()
            Task { await UnreadManager.shared.refresh(currentUid: authViewModel.uid) }
        }
    }

    private var chatSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(vm.messages) { msg in
                        dmBubble(msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
            .refreshable { await vm.refresh() }
            .onChange(of: vm.messages.count) { _, _ in
                if let last = vm.messages.last?.id {
                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
        }
    }

    private func dmBubble(_ msg: DirectMessage) -> some View {
        let isMine = msg.senderId == vm.currentUid
        return HStack(alignment: .bottom, spacing: 8) {
            if isMine {
                Spacer(minLength: 60)
            } else {
                AvatarImage(
                    urlString: msg.senderAvatarURL,
                    name: msg.senderName,
                    size: 28,
                    fontSize: 12
                )
            }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                Text(msg.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isMine ? Color.orange : Color(.systemGray5))
                    .foregroundColor(isMine ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text(msg.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }

            if isMine {
                AvatarImage(
                    urlString: msg.senderAvatarURL,
                    name: msg.senderName,
                    size: 28,
                    fontSize: 12
                )
            } else {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Message…", text: $vm.draftText)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit {
                    vm.send(senderName: authViewModel.displayName, senderAvatarURL: authViewModel.avatarURL)
                }
            Button {
                vm.send(senderName: authViewModel.displayName, senderAvatarURL: authViewModel.avatarURL)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(vm.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .orange)
            }
            .disabled(vm.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
    }
}

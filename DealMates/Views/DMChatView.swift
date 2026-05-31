import SwiftUI

struct DMChatView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var vm: DMChatViewModel
    @State private var profileTarget: UserProfileSheetTarget?
    @ObservedObject private var cache = UserCache.shared

    init(currentUid: String, otherUid: String) {
        _vm = StateObject(wrappedValue: DMChatViewModel(
            currentUid: currentUid,
            otherUid: otherUid
        ))
    }

    private var otherUserDisplayName: String {
        cache.name(for: vm.otherUid, fallback: AppLocalization.string("User"))
    }

    var body: some View {
        ZStack {
            Color.pinCream.ignoresSafeArea()

            VStack(spacing: 0) {
                chatSection
                composer
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    LiveAvatar(userId: vm.otherUid, size: 26, fontSize: 12)
                    Text(otherUserDisplayName)
                        .font(.pinBody(15, weight: .medium))
                        .foregroundStyle(Color.pinInk)
                }
            }
        }
        .toolbarBackground(Color.pinCream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            vm.startListening()
            UnreadManager.shared.markRead(chatId: "dm-\(vm.otherUid)")
        }
        .onDisappear {
            vm.stopListening()
            Task { await UnreadManager.shared.refresh(currentUid: authViewModel.uid) }
        }
        .sheet(item: $profileTarget) { target in
            UserProfileView(userId: target.id)
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
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .refreshable {
                await vm.refresh()
                await UnreadManager.shared.refresh(currentUid: authViewModel.uid)
            }
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
                Button {
                    profileTarget = UserProfileSheetTarget(id: msg.senderId)
                } label: {
                    LiveAvatar(
                        userId: msg.senderId,
                        size: 28,
                        fontSize: 12,
                        fallbackName: msg.senderName,
                        fallbackAvatarURL: msg.senderAvatarURL
                    )
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                Text(msg.text)
                    .font(.pinBody(14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isMine ? Color.pinClay : Color.pinShell)
                    )
                    .foregroundStyle(isMine ? Color.pinCream : Color.pinInk)
                Text(msg.timestamp, style: .time)
                    .font(.pinSubtitle(10))
                    .foregroundStyle(Color.pinInkMuted)
                    .padding(.horizontal, 4)
            }

            if isMine {
                LiveAvatar(
                    userId: msg.senderId,
                    size: 28,
                    fontSize: 12,
                    fallbackName: msg.senderName,
                    fallbackAvatarURL: msg.senderAvatarURL
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
                .font(.pinBody(15))
                .foregroundStyle(Color.pinInk)
                .tint(Color.pinClay)
                .submitLabel(.send)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.pinShell)
                )
                .onSubmit { vm.send() }
            Button {
                vm.send()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.pinCream)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(
                            vm.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.pinInkMuted.opacity(0.4)
                                : Color.pinClay
                        )
                    )
            }
            .buttonStyle(.plain)
            .disabled(vm.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.pinCream)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.pinFog).frame(height: 1)
        }
    }
}

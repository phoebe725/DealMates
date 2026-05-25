import SwiftUI

struct ChatView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject var chatViewModel: ChatViewModel
    @FocusState private var isTextFieldFocused

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8, pinnedViews: []) {
                        ForEach(chatViewModel.messages) { message in
                            ChatBubbleView(message: message, isCurrentUser: message.senderId == authViewModel.uid)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
                .onChange(of: chatViewModel.messages.count) { oldCount, newCount in
                    if newCount > oldCount {
                        withAnimation {
                            proxy.scrollTo(chatViewModel.messages.last?.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input field
            HStack(spacing: 10) {
                TextField("Type a message...", text: $chatViewModel.draftText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)

                Button {
                    chatViewModel.send(senderId: authViewModel.uid, senderName: authViewModel.displayName)
                    isTextFieldFocused = false
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.orange)
                        .clipShape(Circle())
                }
                .disabled(chatViewModel.draftText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
            .background(Color(.systemBackground))
        }
        .onAppear {
            chatViewModel.startListening()
        }
        .onDisappear {
            chatViewModel.stopListening()
        }
    }
}

#Preview {
    ChatView(chatViewModel: ChatViewModel(planId: "test-plan-123"))
        .environmentObject(AuthViewModel())
}

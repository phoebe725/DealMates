import SwiftUI

enum MessagesFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case dm = "DMs"
    case group = "Groups"
    var id: String { rawValue }
}

struct MessagesView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var vm = MessagesListViewModel()
    @ObservedObject private var unread = UnreadManager.shared
    @State private var filter: MessagesFilter = .all

    private var visibleItems: [ConversationItem] {
        switch filter {
        case .all:   return vm.items
        case .dm:    return vm.items.filter { if case .dm = $0.kind { return true } else { return false } }
        case .group: return vm.items.filter { if case .plan = $0.kind { return true } else { return false } }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Filter", selection: $filter) {
                    ForEach(MessagesFilter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Group {
                    if vm.isLoading && vm.items.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if visibleItems.isEmpty {
                        emptyState
                    } else {
                        list
                    }
                }
            }
            .navigationTitle("Messages")
            .onAppear {
                Task {
                    await vm.load(currentUid: authViewModel.uid)
                    await UnreadManager.shared.refresh(currentUid: authViewModel.uid)
                }
            }
            .refreshable {
                await vm.load(currentUid: authViewModel.uid)
                await UnreadManager.shared.refresh(currentUid: authViewModel.uid)
            }
        }
    }

    private var list: some View {
        List(visibleItems) { item in
            NavigationLink {
                destination(for: item)
            } label: {
                row(for: item)
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func destination(for item: ConversationItem) -> some View {
        switch item.kind {
        case .dm(let uid, let name, let avatar):
            DMChatView(
                currentUid: authViewModel.uid,
                otherUid: uid,
                otherName: name,
                otherAvatarURL: avatar
            )
        case .plan(let plan):
            PlanDetailView(plan: plan, planVM: PlanViewModel(restaurantId: plan.restaurantId))
        }
    }

    private func row(for item: ConversationItem) -> some View {
        let notMine = item.lastSenderId != authViewModel.uid
        let isUnread = notMine && unread.isUnread(chatId: item.chatId, lastActivity: item.lastTimestamp)
        return HStack(spacing: 12) {
            AvatarImage(
                urlString: item.avatarURL,
                name: item.title,
                size: 44,
                fontSize: 18
            )
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.subheadline.weight(isUnread ? .bold : .semibold))
                    if case .plan = item.kind {
                        Text("Group")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                    }
                    if isUnread {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                    }
                }
                if let sub = item.subtitle {
                    Text(sub)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text(item.lastMessage)
                    .font(.caption)
                    .foregroundColor(isUnread ? .primary : .secondary)
                    .fontWeight(isUnread ? .semibold : .regular)
                    .lineLimit(1)
            }
            Spacer()
            Text(item.lastTimestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .listRowBackground(isUnread ? Color.orange.opacity(0.07) : Color.clear)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text("No messages yet")
                .font(.headline)
            Text("Join a plan or message an organiser to start.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

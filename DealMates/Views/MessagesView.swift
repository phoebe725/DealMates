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
    @ObservedObject private var userCache = UserCache.shared
    @ObservedObject private var restaurantCache = RestaurantCache.shared
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
                    ForEach(MessagesFilter.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
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
        case .dm(let uid):
            DMChatView(
                currentUid: authViewModel.uid,
                otherUid: uid
            )
        case .plan(let plan):
            PlanDetailView(plan: plan, planVM: PlanViewModel(restaurantId: plan.restaurantId))
        }
    }

    private func row(for item: ConversationItem) -> some View {
        let isSystem = item.lastIsSystem
        let notMine = item.lastSenderId != authViewModel.uid && !isSystem
        let isUnread = notMine && unread.isUnread(chatId: item.chatId, lastActivity: item.lastTimestamp)

        // Resolve live title/avatar/preview from the cache so a profile edit reflects everywhere
        // — even on threads from months ago.
        let liveTitle: String
        let liveAvatarUserId: String?
        switch item.kind {
        case .dm(let uid):
            liveTitle = userCache.name(for: uid, fallback: item.fallbackTitle)
            liveAvatarUserId = uid
        case .plan(let plan):
            // Restaurant name is the title for group chats; avatar mirrors the organiser.
            liveTitle = restaurantCache.displayName(for: plan.restaurantId, fallback: plan.restaurantName)
            liveAvatarUserId = plan.creatorId
        }

        let previewText: String = {
            if isSystem {
                // Localize "X joined the plan" style messages on the fly.
                if let kind = item.lastSystemKind, let args = item.lastSystemArgs {
                    let names = args.map { userCache.name(for: $0, fallback: NSLocalizedString("Diner", comment: "")) }
                    let key: String
                    switch kind {
                    case "joined":         key = "system.joined"
                    case "left":           key = "system.left"
                    case "left_promoted":  key = "system.left_promoted"
                    case "removed":        key = "system.removed"
                    default:               return item.lastMessageText
                    }
                    let format = NSLocalizedString(key, comment: "")
                    return String(format: format, arguments: names.map { $0 as CVarArg })
                }
                return item.lastMessageText
            }
            if case .plan = item.kind, let senderId = item.lastSenderId, senderId != "system" {
                let senderName = userCache.name(for: senderId, fallback: "Someone")
                return "\(senderName): \(item.lastMessageText)"
            }
            return item.lastMessageText
        }()

        return HStack(spacing: 12) {
            if let uid = liveAvatarUserId {
                LiveAvatar(
                    userId: uid,
                    size: 44,
                    fontSize: 18,
                    fallbackName: item.fallbackTitle,
                    fallbackAvatarURL: item.fallbackAvatarURL
                )
            } else {
                AvatarImage(
                    urlString: item.fallbackAvatarURL,
                    name: item.fallbackTitle,
                    size: 44,
                    fontSize: 18
                )
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(liveTitle)
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
                Text(previewText)
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

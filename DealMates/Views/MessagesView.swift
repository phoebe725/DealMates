import SwiftUI

enum MessagesFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case dm = "DMs"
    case group = "Plans"
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
            ZStack {
                Color.pinCream.ignoresSafeArea()

                // ScrollView is the body's only child and its content shape
                // never changes — header is always the first child, ForEach is
                // always present (renders zero rows when items is empty), and
                // the loading / empty states are *siblings* of the ForEach
                // rather than `if/else` branches that swap the LazyVStack's
                // child types. That structural stability is what keeps
                // `.refreshable`'s gesture anchor alive across data refreshes
                // (e.g. coming back from DMChatView after sending a message).
                list
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                // Refresh every time we land on this tab — picks up DMs/plans
                // that arrived while we were elsewhere.
                Task {
                    await vm.load(currentUid: authViewModel.uid)
                    await UnreadManager.shared.refresh(currentUid: authViewModel.uid)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                (
                    Text("Your ")
                        .font(.pinHero(28, weight: .light))
                        .foregroundStyle(Color.pinInk)
                    +
                    Text("messages.")
                        .font(.pinAccent(38))
                        .foregroundStyle(Color.pinClayDeep)
                )
                .lineLimit(1)
                Text("Pin chats and direct messages.")
                    .font(.pinSubtitle(13))
                    .foregroundStyle(Color.pinInkMuted)
            }

            PinSegmentedPicker(
                options: [(value: MessagesFilter.all, label: "All"),
                          (value: MessagesFilter.dm, label: "DMs"),
                          (value: MessagesFilter.group, label: "Plans")],
                counts: filterCounts,
                selection: $filter
            )
        }
    }

    /// Per-filter unread counts shown as chips on the segmented picker. "All"
    /// gets the same total that the tab badge shows; the per-bucket counts
    /// come straight from `UnreadManager` so they update in real-time as
    /// messages arrive and disappear when the user reads a chat.
    private var filterCounts: [MessagesFilter: Int] {
        [.all:   unread.totalUnread,
         .dm:    unread.unreadDMCount,
         .group: unread.unreadPlanCount]
    }

    // MARK: - List
    //
    // Populated state uses a single ScrollView so `.refreshable` stays anchored
    // across data refreshes (e.g. returning from DMChatView). The empty and
    // loading states are rendered OUTSIDE the scroll — header pinned to the top,
    // artwork filling the remaining height — so they sit at the exact same
    // height/format as MyPlansView's empty state. (Pull-to-refresh isn't needed
    // on an empty list; `.onAppear` already refreshes on tab landing.)

    @ViewBuilder
    private var list: some View {
        if vm.isLoading && vm.items.isEmpty {
            VStack(spacing: 0) {
                headerBlock
                ScrollView { loadingState.containerRelativeFrame(.vertical) }
                    .refreshable { await refresh() }
            }
        } else if visibleItems.isEmpty {
            VStack(spacing: 0) {
                headerBlock
                ScrollView { emptyState.containerRelativeFrame(.vertical) }
                    .refreshable { await refresh() }
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    header
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                    ForEach(visibleItems) { item in
                        NavigationLink {
                            destination(for: item)
                        } label: {
                            row(for: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .refreshable { await refresh() }
        }
    }

    private func refresh() async {
        await vm.load(currentUid: authViewModel.uid)
        await UnreadManager.shared.refresh(currentUid: authViewModel.uid)
    }

    /// Header with the standard tab insets — used by the empty / loading states
    /// where the header sits outside the scroll (matching MyPlansView).
    private var headerBlock: some View {
        header
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
    }

    @ViewBuilder
    private func destination(for item: ConversationItem) -> some View {
        switch item.kind {
        case .dm(let uid):
            DMChatView(currentUid: authViewModel.uid, otherUid: uid)
        case .plan(let plan):
            PlanDetailView(plan: plan, planVM: PlanViewModel(restaurantId: plan.restaurantId))
        }
    }

    private func row(for item: ConversationItem) -> some View {
        let isSystem = item.lastIsSystem
        // System messages (joins/leaves) count as unread activity — only
        // messages the current user sent themselves are excluded.
        let notMine = item.lastSenderId != authViewModel.uid
        let isUnread = notMine && unread.isUnread(chatId: item.chatId, lastActivity: item.lastTimestamp)

        let liveTitle: String
        let liveAvatarUserId: String?
        switch item.kind {
        case .dm(let uid):
            liveTitle = userCache.name(for: uid, fallback: item.fallbackTitle)
            liveAvatarUserId = uid
        case .plan(let plan):
            liveTitle = restaurantCache.displayName(for: plan.restaurantId, fallback: plan.restaurantName)
            liveAvatarUserId = plan.creatorId
        }

        let previewText: String = {
            if isSystem {
                if let kind = item.lastSystemKind, let args = item.lastSystemArgs {
                    let names = args.map { userCache.name(for: $0, fallback: AppLocalization.string("Diner")) }
                    let key: String
                    switch kind {
                    case "joined":         key = "system.joined"
                    case "left":           key = "system.left"
                    case "left_promoted":  key = "system.left_promoted"
                    case "removed":        key = "system.removed"
                    default:               return item.lastMessageText
                    }
                    let format = AppLocalization.string(key)
                    return String(format: format, arguments: names.map { $0 as CVarArg })
                }
                return item.lastMessageText
            }
            if case .plan = item.kind, let senderId = item.lastSenderId, senderId != "system" {
                let senderName = userCache.name(for: senderId, fallback: AppLocalization.string("Someone"))
                return "\(senderName): \(item.lastMessageText)"
            }
            return item.lastMessageText
        }()

        return HStack(spacing: 12) {
            if let uid = liveAvatarUserId {
                LiveAvatar(
                    userId: uid,
                    size: 46,
                    fontSize: 18,
                    fallbackName: item.fallbackTitle,
                    fallbackAvatarURL: item.fallbackAvatarURL
                )
            } else {
                AvatarImage(
                    urlString: item.fallbackAvatarURL,
                    name: item.fallbackTitle,
                    size: 46,
                    fontSize: 18
                )
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(liveTitle)
                        .font(.pinBody(15, weight: .medium))
                        .foregroundStyle(Color.pinInk)
                    if case .plan = item.kind {
                        // Sun-yellow chip so plan chats are visually distinct
                        // from one-on-one DMs in the list.
                        PinChip(text: "Plan", tint: .pinSunDeep)
                    }
                    Spacer()
                    Text(item.lastTimestamp, style: .time)
                        .font(.pinSubtitle(11))
                        .foregroundStyle(Color.pinInkMuted)
                }
                Text(previewText)
                    .font(.pinSubtitle(13))
                    .foregroundStyle(isUnread ? Color.pinInk : Color.pinInkMuted)
                    .lineLimit(1)
            }

            if isUnread {
                Circle()
                    .fill(Color.pinClay)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(14)
        .pinCard(fill: isUnread ? Color.pinClay.opacity(0.08) : Color.pinShell)
    }

    // MARK: - Empty / loading

    private var emptyState: some View {
        PinEmptyState(
            title: "No messages yet",
            message: "Join a pin or message an organiser to start a thread.",
            systemImage: "bubble.left.and.bubble.right"
        )
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView().tint(Color.pinInkMuted)
            Text("Loading your messages…")
                .font(.pinSubtitle(14))
                .foregroundStyle(Color.pinInkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

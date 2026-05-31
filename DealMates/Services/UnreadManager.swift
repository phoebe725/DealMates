import Foundation
import Combine

@MainActor
final class UnreadManager: ObservableObject {
    static let shared = UnreadManager()

    /// Total count of conversations where the latest activity hasn't been
    /// seen yet — sum of `unreadDMCount` and `unreadPlanCount`. Displayed as
    /// the badge on the Messages tab.
    @Published private(set) var totalUnread: Int = 0

    /// Unread DM conversations only — shown next to the "DMs" filter chip on
    /// MessagesView.
    @Published private(set) var unreadDMCount: Int = 0

    /// Unread plan/raft chats only — shown next to the "Rafts" filter chip
    /// on MessagesView.
    @Published private(set) var unreadPlanCount: Int = 0

    /// Count of the signed-in user's plans still recruiting (group not yet
    /// full, attendance not confirmed). Combined with `readyToGoCount` to
    /// produce the My Plans tab badge.
    @Published private(set) var activeCount: Int = 0

    /// Count of the signed-in user's plans that are full but not yet
    /// attendance-confirmed.
    @Published private(set) var readyToGoCount: Int = 0

    private let defaults = UserDefaults.standard
    private let service = DatabaseService.shared

    /// Realtime listeners (messages, direct_messages, plans). One per table.
    private var listenerTasks: [Task<Void, Never>] = []
    /// In-flight refresh. New refreshes cancel and supersede it — the latest
    /// pull-to-refresh always wins, never gets dropped on the floor. Cancelling
    /// before publishing is safe because `doRefresh` only assigns at the end
    /// after all fetches succeed; a cancelled fetch publishes nothing.
    private var refreshTask: Task<Void, Never>?

    private var currentUidHint: String = ""

    private init() {}

    // MARK: - Read state

    private func lastSeenKey(for chatId: String) -> String { "unread.lastSeen.\(chatId)" }

    func lastSeen(for chatId: String) -> Date {
        if let t = defaults.object(forKey: lastSeenKey(for: chatId)) as? Date { return t }
        return .distantPast
    }

    func markRead(chatId: String) {
        defaults.set(Date(), forKey: lastSeenKey(for: chatId))
        triggerRefresh()
    }

    func isUnread(chatId: String, lastActivity: Date) -> Bool {
        lastActivity > lastSeen(for: chatId)
    }

    // MARK: - Refresh

    func refresh(currentUid: String) async {
        guard !currentUid.isEmpty else { return }
        currentUidHint = currentUid
        // Supersede any in-flight refresh — the newest caller wins. We never
        // skip a manual pull-to-refresh; instead the older fetch is cancelled
        // (it hadn't published yet anyway, since `doRefresh` only assigns at
        // the end). This serializes work without dropping it.
        refreshTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            await self.doRefresh(currentUid: currentUid)
        }
        refreshTask = task
        await task.value
    }

    private func doRefresh(currentUid: String) async {
        // `fetchMyOpenPlans` filters on the DB side to plans whose attendance
        // hasn't been confirmed yet. That gives us the same plan set
        // MyPlansView counts in its Active / Ready-to-go buckets — including
        // plans whose `expires_at` is in the past but whose attendance hasn't
        // been recorded — while staying away from old historical rows that
        // could fail to decode if pre-migration columns are NULL.
        let openPlans: [Plan]
        let dms: [DMConversation]
        do {
            async let plansTask = service.fetchMyOpenPlans(userId: currentUid)
            async let dmsTask = service.fetchConversations(currentUid: currentUid)
            openPlans = try await plansTask
            dms = try await dmsTask
        } catch {
            // Treat fetch failures as "don't update" — never as "set to
            // zero". A network blip used to drop badges to nil and bring
            // them back. Log so we can spot RLS / query issues.
            print("[DEBUG] UnreadManager.doRefresh: fetch failed: \(error)")
            return
        }
        if Task.isCancelled { return }

        let latestByPlan = (try? await service.fetchLatestMessages(planIds: openPlans.map(\.id))) ?? [:]
        if Task.isCancelled { return }

        var unreadPlans = 0
        var unreadDMs = 0
        var active = 0
        var ready = 0
        for plan in openPlans {
            // Active: still recruiting. Ready: group is full but attendance
            // hasn't been recorded. Completed plans were filtered above.
            if plan.needsMorePeople > 0 {
                active += 1
            } else {
                ready += 1
            }
            guard let msg = latestByPlan[plan.id] else { continue }
            // Don't count your own messages or system messages (joins/leaves/etc.).
            if msg.senderId == currentUid { continue }
            if msg.isSystem { continue }
            if msg.timestamp > lastSeen(for: "plan-\(plan.id)") {
                unreadPlans += 1
            }
        }
        for dm in dms {
            if dm.lastSenderId == currentUid { continue }
            if dm.lastTimestamp > lastSeen(for: "dm-\(dm.otherUserId)") {
                unreadDMs += 1
            }
        }
        let unread = unreadPlans + unreadDMs

        print("[DEBUG] UnreadManager.doRefresh: dms=\(unreadDMs) plans=\(unreadPlans) total=\(unread) active=\(active) ready=\(ready)")

        // Only assign when the value actually changed — avoids a published
        // event that re-renders ContentView for nothing.
        if totalUnread != unread { totalUnread = unread }
        if unreadDMCount != unreadDMs { unreadDMCount = unreadDMs }
        if unreadPlanCount != unreadPlans { unreadPlanCount = unreadPlans }
        if activeCount != active { activeCount = active }
        if readyToGoCount != ready { readyToGoCount = ready }
    }

    /// Fires a refresh immediately. Coalescing is already handled by
    /// `refresh()` itself — each call cancels the prior in-flight task — so we
    /// don't need a sleep-based debounce. Eliminating the 300ms wait is what
    /// makes the tab badges update in real-time when an event arrives while
    /// the user is on a different tab.
    private func triggerRefresh() {
        let uid = currentUidHint
        guard !uid.isEmpty else { return }
        Task { [weak self] in await self?.refresh(currentUid: uid) }
    }

    // MARK: - Realtime

    /// Open three realtime channels — new chat messages, new DMs, and any
    /// plan changes (so a member-joined or attendance-confirmed event also
    /// repaints the badges). Idempotent: existing listeners are torn down
    /// before new ones are started.
    func startListening(currentUid: String) {
        stopListening()
        guard !currentUid.isEmpty else { return }
        currentUidHint = currentUid
        print("[DEBUG] UnreadManager.startListening uid=\(currentUid)")

        listenerTasks.append(service.listenToAllMessageInserts { [weak self] in
            print("[DEBUG] UnreadManager: message INSERT received")
            self?.triggerRefresh()
        })
        listenerTasks.append(service.listenToAllDMInserts { [weak self] in
            print("[DEBUG] UnreadManager: DM INSERT received")
            self?.triggerRefresh()
        })
        listenerTasks.append(service.listenToAllPlanChanges { [weak self] in
            print("[DEBUG] UnreadManager: plan CHANGE received")
            self?.triggerRefresh()
        })
    }

    func stopListening() {
        listenerTasks.forEach { $0.cancel() }
        listenerTasks = []
        refreshTask?.cancel()
        refreshTask = nil
    }
}

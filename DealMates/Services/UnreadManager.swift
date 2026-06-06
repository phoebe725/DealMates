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

    /// Unread plan group-chat messages only — counted toward `totalUnread`
    /// (the Messages tab badge) alongside DMs.
    @Published private(set) var unreadPlanCount: Int = 0

    /// Unread plan *actions* (system messages — someone joined/left/was
    /// removed) across the user's open plans. Drives the My Plans tab badge.
    @Published private(set) var unreadActionCount: Int = 0

    /// Count of the signed-in user's plans still recruiting (group not yet
    /// full, attendance not confirmed). Surfaced as bucket counts on the My
    /// Plans segmented control.
    @Published private(set) var activeCount: Int = 0

    /// Count of the signed-in user's plans that are full but not yet
    /// attendance-confirmed.
    @Published private(set) var readyToGoCount: Int = 0

    /// Plan IDs that have unread chat messages or system actions (joins/leaves)
    /// since the user last viewed them. Drives per-row dots in MyPlansView and
    /// MessagesView.
    @Published private(set) var unreadPlanIds: Set<String> = []

    /// Other-user IDs of DM threads with unread messages. Drives DM row dots —
    /// so the Messages badge always equals (unreadPlanIds + unreadDMIds).count.
    @Published private(set) var unreadDMIds: Set<String> = []

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
        // Single source of truth: ALL the user's plans — exactly the set the
        // Messages list and My Plans list render. Computing the badge over any
        // narrower set (e.g. non-expired only) causes the badge to count a plan
        // that the Messages list doesn't show — the badge/row mismatch bug.
        let allPlans: [Plan]
        let dms: [DMConversation]
        do {
            async let plansTask = service.fetchMyPlans(userId: currentUid)
            async let dmsTask = service.fetchConversations(currentUid: currentUid)
            allPlans = try await plansTask
            dms = try await dmsTask
        } catch {
            // Treat fetch failures as "don't update" — never as "set to
            // zero". A network blip used to drop badges to nil and bring
            // them back. Log so we can spot RLS / query issues.
            print("[DEBUG] UnreadManager.doRefresh: fetch failed: \(error)")
            return
        }
        if Task.isCancelled { return }

        let planIds = allPlans.map(\.id)
        let latestByPlan = (try? await service.fetchLatestMessages(planIds: planIds)) ?? [:]
        let systemMsgs = (try? await service.fetchSystemMessages(planIds: planIds)) ?? []
        if Task.isCancelled { return }

        var unreadActions = 0
        var active = 0
        var ready = 0
        var newUnreadPlanIds = Set<String>()
        var newUnreadDMIds = Set<String>()

        // System actions (joins/leaves) — drive My Plans tab badge AND row dots.
        for msg in systemMsgs where msg.timestamp > lastSeen(for: "plan-\(msg.planId)") {
            unreadActions += 1
            newUnreadPlanIds.insert(msg.planId)
        }

        for plan in allPlans {
            // Active / Ready buckets only count plans still open (attendance not
            // yet confirmed) — matches MyPlansView's bucketing.
            if plan.attendanceConfirmedAt == nil {
                if plan.needsMorePeople > 0 { active += 1 } else { ready += 1 }
            }
            guard let msg = latestByPlan[plan.id] else { continue }
            // Own messages are never unread. System messages already handled above.
            if msg.senderId == currentUid { continue }
            if msg.isSystem { continue }
            if msg.timestamp > lastSeen(for: "plan-\(plan.id)") {
                newUnreadPlanIds.insert(plan.id)
            }
        }
        for dm in dms {
            if dm.lastSenderId == currentUid { continue }
            if dm.lastTimestamp > lastSeen(for: "dm-\(dm.otherUserId)") {
                newUnreadDMIds.insert(dm.otherUserId)
            }
        }
        // Badge = exactly the rows that get a dot. Both derive from the same
        // sets, so the count can never disagree with the highlighted rows.
        let unreadPlans = newUnreadPlanIds.count
        let unreadDMs = newUnreadDMIds.count
        let unread = unreadPlans + unreadDMs

        print("[DEBUG] UnreadManager.doRefresh: dms=\(unreadDMs) plans=\(unreadPlans) actions=\(unreadActions) total=\(unread) active=\(active) ready=\(ready)")

        if totalUnread    != unread         { totalUnread    = unread }
        if unreadDMCount  != unreadDMs      { unreadDMCount  = unreadDMs }
        if unreadPlanCount != unreadPlans   { unreadPlanCount = unreadPlans }
        if unreadActionCount != unreadActions { unreadActionCount = unreadActions }
        if activeCount    != active         { activeCount    = active }
        if readyToGoCount != ready          { readyToGoCount = ready }
        if unreadPlanIds  != newUnreadPlanIds { unreadPlanIds = newUnreadPlanIds }
        if unreadDMIds    != newUnreadDMIds  { unreadDMIds = newUnreadDMIds }
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

import Foundation
import Supabase

// MARK: - DatabaseService

/// All Supabase database operations: restaurants, plans, messages, and real-time listeners.
final class DatabaseService {
    static let shared = DatabaseService()
    private var client: SupabaseClient { SupabaseManager.shared.client }

    private init() {}

    // MARK: - Restaurants

    func fetchRestaurants() async throws -> [Restaurant] {
        let results: [Restaurant] = try await client.from("restaurants").select().order("name", ascending: true).execute().value
        return results
    }

    func fetchRestaurant(id: String) async throws -> Restaurant? {
        let results: [Restaurant] = try await client
            .from("restaurants").select().eq("id", value: id).limit(1).execute().value
        return results.first
    }

    /// All active offers, grouped by restaurant_id. Returns [:] if the table is
    /// missing or errors.
    func fetchOffersMap() async -> [String: [RestaurantOffer]] {
        do {
            let rows: [RestaurantOffer] = try await client
                .from("restaurant_offers").select()
                .eq("is_active", value: true)
                .order("offer_order", ascending: true)
                .execute().value
            return Dictionary(grouping: rows, by: { $0.restaurantId })
        } catch {
            print("[DEBUG] fetchOffersMap failed (falling back to deals JSON): \(error)")
            return [:]
        }
    }

    /// Active offers for one restaurant (empty if none / table missing).
    func fetchOffers(restaurantId: String) async -> [RestaurantOffer] {
        do {
            return try await client
                .from("restaurant_offers").select()
                .eq("restaurant_id", value: restaurantId)
                .eq("is_active", value: true)
                .order("offer_order", ascending: true)
                .execute().value
        } catch {
            return []
        }
    }

    /// Upserts a restaurant by `id` and returns the canonical row. Used when a
    /// user pins a plan at a MapKit search result that isn't in the curated set,
    /// and by the admin "add restaurant" flow. Conflicts update in place so a
    /// place added twice doesn't duplicate.
    @discardableResult
    func upsertRestaurant(_ restaurant: Restaurant) async throws -> Restaurant {
        let rows: [Restaurant] = try await client
            .from("restaurants")
            .upsert(restaurant, onConflict: "id")
            .select()
            .execute()
            .value
        return rows.first ?? restaurant
    }

    // MARK: - Admin: curation

    func setRestaurantFeatured(id: String, isFeatured: Bool) async throws {
        struct Patch: Encodable {
            let isFeatured: Bool
            enum CodingKeys: String, CodingKey { case isFeatured = "is_featured" }
        }
        try await client.from("restaurants")
            .update(Patch(isFeatured: isFeatured)).eq("id", value: id).execute()
    }

    // MARK: - Plans

    func fetchActivePlans(restaurantId: String) async throws -> [Plan] {
        let now = ISO8601DateFormatter().string(from: Date())
        let plans: [Plan] = try await client
            .from("plans")
            .select()
            .eq("restaurant_id", value: restaurantId)
            .gt("expires_at", value: now)
            .order("scheduled_at", ascending: true)
            .execute()
            .value
        return plans
    }

    /// Look up a plan by its short event code (e.g. PT482). Case-insensitive.
    /// Mirrors web's `fetchPlanByCode`.
    func fetchPlanByCode(_ code: String) async throws -> Plan? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let results: [Plan] = try await client
            .from("plans")
            .select()
            .ilike("event_code", value: trimmed)
            .limit(1)
            .execute()
            .value
        return results.first
    }

    /// Returns plans where the current user is a member and which haven't expired.
    func fetchMyActivePlans(userId: String) async throws -> [Plan] {
        let now = ISO8601DateFormatter().string(from: Date())
        let plans: [Plan] = try await client
            .from("plans")
            .select()
            .contains("member_ids", value: [userId])
            .gt("expires_at", value: now)
            .order("scheduled_at", ascending: true)
            .execute()
            .value
        return plans
    }

    /// Returns ALL of the user's plans — active + confirmed + any historical ones —
    /// used to populate the "Completed" bucket on MyPlans.
    func fetchMyPlans(userId: String) async throws -> [Plan] {
        try await client
            .from("plans")
            .select()
            .contains("member_ids", value: [userId])
            .order("scheduled_at", ascending: false)
            .execute()
            .value
    }

    /// Returns the user's plans that haven't been attendance-confirmed —
    /// i.e. anything still in the Active or Ready-to-go bucket, regardless of
    /// `expires_at`. Used by `UnreadManager` so the tab badge matches the
    /// bucket totals in MyPlansView even when a plan's scheduled time has
    /// passed but the organiser hasn't recorded attendance yet.
    func fetchMyOpenPlans(userId: String) async throws -> [Plan] {
        try await client
            .from("plans")
            .select()
            .contains("member_ids", value: [userId])
            .is("attendance_confirmed_at", value: nil)
            .order("scheduled_at", ascending: true)
            .execute()
            .value
    }

    func createPlan(_ plan: Plan) async throws {
        try await client.from("plans").insert(plan).execute()
    }

    func updatePlan(_ plan: Plan) async throws {
        try await client.from("plans").update(plan).eq("id", value: plan.id).execute()
    }

    /// Single plan by id — used to open a shared plan link (pintable://plan/<id>).
    func fetchPlan(id: String) async throws -> Plan? {
        let rows: [Plan] = try await client
            .from("plans").select().eq("id", value: id).limit(1).execute().value
        return rows.first
    }

    func deletePlan(planId: String) async throws {
        try await client.from("plans").delete().eq("id", value: planId).execute()
    }

    func joinPlan(_ plan: Plan, userId: String, userName: String) async throws {
        guard !plan.memberIds.contains(userId) else { return }
        let newIds    = plan.memberIds + [userId]
        let newCount  = plan.currentPeople + 1
        struct Patch: Encodable {
            let memberIds: [String]
            let currentPeople: Int
            enum CodingKeys: String, CodingKey {
                case memberIds = "member_ids"
                case currentPeople = "current_people"
            }
        }
        try await client.from("plans")
            .update(Patch(memberIds: newIds, currentPeople: newCount))
            .eq("id", value: plan.id)
            .execute()
        try await postSystemMessage(
            planId: plan.id,
            fallbackText: "\(userName) joined the plan 🙌",
            kind: "joined",
            args: [userId]
        )
    }

    func leavePlan(_ plan: Plan, userId: String, userName: String) async throws {
        guard plan.memberIds.contains(userId) else { return }
        let newIds   = plan.memberIds.filter { $0 != userId }
        let newCount = max(1, plan.currentPeople - 1)

        // Organiser succession: if the leaver is the creator and other members remain,
        // promote the next-earliest member (first in the trimmed list).
        if plan.creatorId == userId, let nextUid = newIds.first,
           let nextUser = try? await fetchUser(id: nextUid) {
            struct Patch: Encodable {
                let memberIds: [String]
                let currentPeople: Int
                let creatorId: String
                let creatorName: String
                let creatorAvatarURL: String?
                enum CodingKeys: String, CodingKey {
                    case memberIds = "member_ids"
                    case currentPeople = "current_people"
                    case creatorId = "creator_id"
                    case creatorName = "creator_name"
                    case creatorAvatarURL = "creator_avatar_url"
                }
            }
            try await client.from("plans")
                .update(Patch(
                    memberIds: newIds,
                    currentPeople: newCount,
                    creatorId: nextUser.id,
                    creatorName: nextUser.displayName,
                    creatorAvatarURL: nextUser.avatarURL
                ))
                .eq("id", value: plan.id)
                .execute()
            try await postSystemMessage(
                planId: plan.id,
                fallbackText: "\(userName) left. \(nextUser.displayName) is now the organiser.",
                kind: "left_promoted",
                args: [userId, nextUser.id]
            )
            return
        }

        struct Patch: Encodable {
            let memberIds: [String]
            let currentPeople: Int
            enum CodingKeys: String, CodingKey {
                case memberIds = "member_ids"
                case currentPeople = "current_people"
            }
        }
        try await client.from("plans")
            .update(Patch(memberIds: newIds, currentPeople: newCount))
            .eq("id", value: plan.id)
            .execute()
        try await postSystemMessage(
            planId: plan.id,
            fallbackText: "\(userName) left the plan",
            kind: "left",
            args: [userId]
        )
    }

    /// Records attendance for a completed plan. Atomically increments attended_count for
    /// each user marked attended and hosted_count for the organiser.
    func confirmAttendance(planId: String, attendedUserIds: [String]) async throws {
        struct Params: Encodable {
            let p_plan_id: String
            let p_attended: [String]
        }
        try await client.rpc("confirm_plan_attendance",
                             params: Params(p_plan_id: planId, p_attended: attendedUserIds))
            .execute()
    }

    func removeMember(_ plan: Plan, targetUid: String, targetName: String,
                      removerUid: String, removerName: String) async throws {
        guard plan.memberIds.contains(targetUid), plan.creatorId != targetUid else { return }
        let newIds = plan.memberIds.filter { $0 != targetUid }
        let newCount = max(1, plan.currentPeople - 1)
        struct Patch: Encodable {
            let memberIds: [String]
            let currentPeople: Int
            enum CodingKeys: String, CodingKey {
                case memberIds = "member_ids"
                case currentPeople = "current_people"
            }
        }
        try await client.from("plans")
            .update(Patch(memberIds: newIds, currentPeople: newCount))
            .eq("id", value: plan.id)
            .execute()
        try await postSystemMessage(
            planId: plan.id,
            fallbackText: "\(removerName) removed \(targetName) from the plan.",
            kind: "removed",
            args: [removerUid, targetUid]
        )
    }

    func fetchUser(id: String) async throws -> AppUser {
        try await client.from("users").select().eq("id", value: id).single().execute().value
    }

    func listenToUser(uid: String, onChange: @escaping () async -> Void) -> Task<Void, Never> {
        Task {
            let channel = client.realtimeV2
                .channel("user-\(uid)-\(UUID().uuidString)")
            let changes = await channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table:  "users",
                filter: "id=eq.\(uid)"
            )
            await channel.subscribe()
            for await _ in changes {
                if Task.isCancelled { break }
                await onChange()
            }
        }
    }

    func fetchUsers(ids: [String]) async throws -> [AppUser] {
        guard !ids.isEmpty else { return [] }
        return try await client.from("users").select().in("id", values: ids).execute().value
    }

    // MARK: - Subscriptions

    func fetchSubscriptions(userId: String) async throws -> [RestaurantSubscription] {
        guard !userId.isEmpty else { return [] }
        return try await client.from("restaurant_subscriptions")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
    }

    func subscribeToRestaurant(userId: String, restaurantId: String) async throws {
        struct Row: Encodable {
            let user_id: String
            let restaurant_id: String
        }
        try await client.from("restaurant_subscriptions")
            .upsert(Row(user_id: userId, restaurant_id: restaurantId))
            .execute()
    }

    func unsubscribeFromRestaurant(userId: String, restaurantId: String) async throws {
        try await client.from("restaurant_subscriptions")
            .delete()
            .eq("user_id", value: userId)
            .eq("restaurant_id", value: restaurantId)
            .execute()
    }

    /// Fetch all active plans across every restaurant (for the global Plans browse view).
    func fetchAllActivePlans() async throws -> [Plan] {
        let now = ISO8601DateFormatter().string(from: Date())
        return try await client.from("plans")
            .select()
            .gt("expires_at", value: now)
            .order("scheduled_at", ascending: true)
            .execute()
            .value
    }

    /// Listen to every insert/update on the `users` table — used by `UserCache` to keep names
    /// and avatars live everywhere (historical chats, plan rows, DM threads).
    ///
    /// Decode is wrapped in a do/catch (instead of `try?`) so failures are visible in the
    /// console rather than silently dropping updates. As a defensive fallback we also try to
    /// pull the affected user's `id` directly from the raw record and refetch via the
    /// regular database path — this way even if the realtime payload's shape drifts from
    /// `AppUser` later, profile renames still propagate.
    func listenToAllUserUpdates(onChange: @escaping (AppUser) -> Void) -> Task<Void, Never> {
        Task {
            let channel = client.realtimeV2
                .channel("users-global-\(UUID().uuidString)")
            let inserts = await channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table:  "users"
            )
            let updates = await channel.postgresChange(
                UpdateAction.self,
                schema: "public",
                table:  "users"
            )
            await channel.subscribe()
            print("[DEBUG] users realtime: subscribed")

            await withTaskGroup(of: Void.self) { group in
                group.addTask { [weak self] in
                    for await action in inserts {
                        if Task.isCancelled { break }
                        do {
                            let user = try action.decodeRecord(
                                as: AppUser.self,
                                decoder: SupabaseManager.shared.decoder
                            )
                            await MainActor.run { onChange(user) }
                        } catch {
                            print("[DEBUG] users realtime insert decode failed: \(error)")
                            await self?.fallbackUserFetch(record: action.record, onChange: onChange)
                        }
                    }
                }
                group.addTask { [weak self] in
                    for await action in updates {
                        if Task.isCancelled { break }
                        do {
                            let user = try action.decodeRecord(
                                as: AppUser.self,
                                decoder: SupabaseManager.shared.decoder
                            )
                            await MainActor.run { onChange(user) }
                        } catch {
                            print("[DEBUG] users realtime update decode failed: \(error)")
                            await self?.fallbackUserFetch(record: action.record, onChange: onChange)
                        }
                    }
                }
            }
        }
    }

    /// When the realtime payload can't be decoded straight to `AppUser`, pull the
    /// `id` field out of the raw record and refetch the user via the regular
    /// query path. That keeps the cache fresh even if the payload's shape drifts.
    private func fallbackUserFetch(record: JSONObject, onChange: @escaping (AppUser) -> Void) async {
        guard case .string(let id)? = record["id"] else {
            print("[DEBUG] users realtime: no id in payload — \(record)")
            return
        }
        do {
            let user = try await fetchUser(id: id)
            await MainActor.run { onChange(user) }
        } catch {
            print("[DEBUG] users realtime: refetch for id \(id) failed: \(error)")
        }
    }

    /// Fires `onInsert` on every new row in the `messages` table. Coarse on
    /// purpose — the caller is responsible for filtering / debouncing.
    func listenToAllMessageInserts(onInsert: @escaping () -> Void) -> Task<Void, Never> {
        Task {
            let channel = client.realtimeV2
                .channel("messages-global-\(UUID().uuidString)")
            let inserts = await channel.postgresChange(
                InsertAction.self, schema: "public", table: "messages"
            )
            await channel.subscribe()
            print("[DEBUG] listenToAllMessageInserts: subscribed")
            for await _ in inserts {
                if Task.isCancelled { break }
                await MainActor.run { onInsert() }
            }
        }
    }

    /// Fires `onInsert` on every new row in the `direct_messages` table.
    func listenToAllDMInserts(onInsert: @escaping () -> Void) -> Task<Void, Never> {
        Task {
            let channel = client.realtimeV2
                .channel("dms-global-\(UUID().uuidString)")
            let inserts = await channel.postgresChange(
                InsertAction.self, schema: "public", table: "direct_messages"
            )
            await channel.subscribe()
            print("[DEBUG] listenToAllDMInserts: subscribed")
            for await _ in inserts {
                if Task.isCancelled { break }
                await MainActor.run { onInsert() }
            }
        }
    }

    /// Fires `onUpdate(plan)` with the new row whenever a plan UPDATE event
    /// arrives via realtime. Used by `NotificationManager` to post local
    /// "X joined" / "raft ready" alerts even while the app is foregrounded.
    func listenToAllPlanUpdates(onUpdate: @escaping (Plan) -> Void) -> Task<Void, Never> {
        Task {
            let channel = client.realtimeV2
                .channel("plans-updates-\(UUID().uuidString)")
            let updates = await channel.postgresChange(
                UpdateAction.self, schema: "public", table: "plans"
            )
            await channel.subscribe()
            print("[DEBUG] listenToAllPlanUpdates: subscribed")
            for await action in updates {
                if Task.isCancelled { break }
                do {
                    let plan = try action.decodeRecord(
                        as: Plan.self,
                        decoder: SupabaseManager.shared.decoder
                    )
                    await MainActor.run { onUpdate(plan) }
                } catch {
                    // Decode failures here would silently swallow the event
                    // and we'd never post a notification — surface them so we
                    // can spot a schema/replica-identity mismatch.
                    print("[DEBUG] listenToAllPlanUpdates: decode failed: \(error)")
                }
            }
        }
    }

    /// Fires `onChange` on every insert / update / delete of `plans`. Used by
    /// `UnreadManager` to recompute the "ready-to-go" tab badge when membership
    /// or attendance state changes.
    func listenToAllPlanChanges(onChange: @escaping () -> Void) -> Task<Void, Never> {
        Task {
            let channel = client.realtimeV2
                .channel("plans-global-changes-\(UUID().uuidString)")
            let changes = await channel.postgresChange(
                AnyAction.self, schema: "public", table: "plans"
            )
            await channel.subscribe()
            print("[DEBUG] listenToAllPlanChanges: subscribed")
            for await _ in changes {
                if Task.isCancelled { break }
                await MainActor.run { onChange() }
            }
        }
    }

    /// Listen to plan inserts across all restaurants — used for local notifications on subscribed restaurants.
    func listenToAllPlanInserts(onInsert: @escaping (Plan) -> Void) -> Task<Void, Never> {
        Task {
            let channel = client.realtimeV2
                .channel("plans-global-\(UUID().uuidString)")
            let inserts = await channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table:  "plans"
            )
            await channel.subscribe()
            for await action in inserts {
                if Task.isCancelled { break }
                if let plan = try? action.decodeRecord(as: Plan.self, decoder: SupabaseManager.shared.decoder) {
                    await MainActor.run { onInsert(plan) }
                }
            }
        }
    }

    // Updates an existing plan's scheduled_at + time_type (used when an ASAP/Flexible plan locks in a time).
    func setPlanScheduledTime(planId: String, scheduledAt: Date) async throws {
        struct Patch: Encodable {
            let scheduledAt: Date
            let timeType: String
            let isAsap: Bool
            let flexDay: String?
            let flexMeal: String?
            let expiresAt: Date
            enum CodingKeys: String, CodingKey {
                case scheduledAt = "scheduled_at"
                case timeType    = "time_type"
                case isAsap      = "is_asap"
                case flexDay     = "flex_day"
                case flexMeal    = "flex_meal"
                case expiresAt   = "expires_at"
            }
        }
        let expiry = scheduledAt.addingTimeInterval(2 * 3600)
        try await client.from("plans")
            .update(Patch(scheduledAt: scheduledAt, timeType: "scheduled", isAsap: false,
                          flexDay: nil, flexMeal: nil, expiresAt: expiry))
            .eq("id", value: planId)
            .execute()
    }

    // MARK: - Polls

    func fetchPolls(planId: String) async throws -> [Poll] {
        try await client.from("polls")
            .select()
            .eq("plan_id", value: planId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func fetchVotes(planId: String) async throws -> [PollVote] {
        struct PollIdOnly: Decodable { let id: String }
        let polls: [PollIdOnly] = try await client.from("polls")
            .select("id")
            .eq("plan_id", value: planId)
            .execute()
            .value
        let pollIds = polls.map(\.id)
        guard !pollIds.isEmpty else { return [] }
        return try await client.from("poll_votes")
            .select()
            .in("poll_id", values: pollIds)
            .execute()
            .value
    }

    func createPoll(_ poll: Poll) async throws {
        try await client.from("polls").insert(poll).execute()
    }

    func castVote(_ vote: PollVote) async throws {
        // Delete-then-insert pattern avoids relying on composite-key upsert syntax.
        try await client.from("poll_votes")
            .delete()
            .eq("poll_id", value: vote.pollId)
            .eq("user_id", value: vote.userId)
            .execute()
        try await client.from("poll_votes").insert(vote).execute()
    }

    func listenToPolls(planId: String, onChange: @escaping () async -> Void) -> Task<Void, Never> {
        Task {
            let channel = client.realtimeV2
                .channel("polls-\(planId)-\(UUID().uuidString)")
            let pollChanges = await channel.postgresChange(
                AnyAction.self, schema: "public", table: "polls",
                filter: "plan_id=eq.\(planId)"
            )
            let voteChanges = await channel.postgresChange(
                AnyAction.self, schema: "public", table: "poll_votes"
            )
            await channel.subscribe()
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await _ in pollChanges {
                        if Task.isCancelled { break }
                        await onChange()
                    }
                }
                group.addTask {
                    for await _ in voteChanges {
                        if Task.isCancelled { break }
                        await onChange()
                    }
                }
            }
        }
    }

    // MARK: - Direct Messages

    func sendDirectMessage(_ message: DirectMessage) async throws {
        try await client.from("direct_messages").insert(message).execute()
    }

    func fetchDirectMessages(currentUid: String, otherUid: String) async throws -> [DirectMessage] {
        let orFilter = "and(sender_id.eq.\(currentUid),recipient_id.eq.\(otherUid)),and(sender_id.eq.\(otherUid),recipient_id.eq.\(currentUid))"
        return try await client.from("direct_messages")
            .select()
            .or(orFilter)
            .order("timestamp", ascending: true)
            .execute()
            .value
    }

    func fetchConversations(currentUid: String) async throws -> [DMConversation] {
        let messages: [DirectMessage] = try await client.from("direct_messages")
            .select()
            .or("sender_id.eq.\(currentUid),recipient_id.eq.\(currentUid)")
            .order("timestamp", ascending: false)
            .execute()
            .value

        var conversations: [String: DMConversation] = [:]
        for msg in messages {
            let isOutgoing = msg.senderId == currentUid
            let otherId = isOutgoing ? msg.recipientId : msg.senderId
            let otherName = isOutgoing ? msg.recipientName : msg.senderName
            let otherAvatar = isOutgoing ? msg.recipientAvatarURL : msg.senderAvatarURL
            if conversations[otherId] == nil {
                conversations[otherId] = DMConversation(
                    otherUserId: otherId,
                    otherUserName: otherName,
                    otherUserAvatarURL: otherAvatar,
                    lastMessage: msg.text,
                    lastTimestamp: msg.timestamp,
                    lastSenderId: msg.senderId
                )
            }
        }
        return conversations.values.sorted { $0.lastTimestamp > $1.lastTimestamp }
    }

    func listenToDirectMessages(
        currentUid: String,
        otherUid: String,
        onInsert: @escaping (DirectMessage) -> Void
    ) -> Task<Void, Never> {
        Task {
            let channel = client.realtimeV2
                .channel("dm-\(min(currentUid, otherUid))-\(max(currentUid, otherUid))-\(UUID().uuidString)")
            let inserts = await channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table:  "direct_messages"
            )
            await channel.subscribe()
            for await action in inserts {
                if Task.isCancelled { break }
                guard let msg = try? action.decodeRecord(as: DirectMessage.self, decoder: SupabaseManager.shared.decoder) else { continue }
                let involvesPair = (msg.senderId == currentUid && msg.recipientId == otherUid) ||
                                   (msg.senderId == otherUid && msg.recipientId == currentUid)
                if involvesPair {
                    await MainActor.run { onInsert(msg) }
                }
            }
        }
    }

    // MARK: - Messages

    func fetchMessages(planId: String) async throws -> [ChatMessage] {
        try await client.from("messages")
            .select()
            .eq("plan_id", value: planId)
            .order("timestamp", ascending: true)
            .execute()
            .value
    }

    /// Latest message per plan for the given plan IDs.
    func fetchLatestMessages(planIds: [String]) async throws -> [String: ChatMessage] {
        guard !planIds.isEmpty else { return [:] }
        let messages: [ChatMessage] = try await client.from("messages")
            .select()
            .in("plan_id", values: planIds)
            .order("timestamp", ascending: false)
            .execute()
            .value
        var latest: [String: ChatMessage] = [:]
        for msg in messages where latest[msg.planId] == nil {
            latest[msg.planId] = msg
        }
        return latest
    }

    /// All system (action) messages — joins/leaves/removals — for the given
    /// plans, newest first. Used to count unread plan *actions* for the My Plans
    /// badge (regular chat messages are counted separately for Messages).
    func fetchSystemMessages(planIds: [String]) async throws -> [ChatMessage] {
        guard !planIds.isEmpty else { return [] }
        return try await client.from("messages")
            .select()
            .in("plan_id", values: planIds)
            .eq("is_system", value: true)
            .order("timestamp", ascending: false)
            .execute()
            .value
    }

    func sendMessage(_ message: ChatMessage) async throws {
        try await client.from("messages").insert(message).execute()
    }

    // MARK: - Real-time listeners

    /// Returns a cancellable `Task` that fires `onChange` whenever any plan row
    /// matching `restaurantId` is inserted / updated / deleted.
    func listenToPlans(
        restaurantId: String,
        onChange: @escaping () async -> Void
    ) -> Task<Void, Never> {
        Task {
            let channel = client.realtimeV2
                .channel("plans-\(restaurantId)-\(UUID().uuidString)")
            let changes = await channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table:  "plans",
                filter: "restaurant_id=eq.\(restaurantId)"
            )
            await channel.subscribe()
            for await _ in changes {
                if Task.isCancelled { break }
                await onChange()
            }
        }
    }

    /// Returns a cancellable `Task` that fires `onInsert` with each new message.
    func listenToMessages(
        planId: String,
        onInsert: @escaping (ChatMessage) -> Void
    ) -> Task<Void, Never> {
        Task {
            let channel = client.realtimeV2
                .channel("messages-\(planId)-\(UUID().uuidString)")
            let inserts = await channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table:  "messages",
                filter: "plan_id=eq.\(planId)"
            )
            await channel.subscribe()
            for await action in inserts {
                if Task.isCancelled { break }
                if let msg = try? action.decodeRecord(
                    as: ChatMessage.self,
                    decoder: SupabaseManager.shared.decoder
                ) {
                    await MainActor.run { onInsert(msg) }
                }
            }
        }
    }

    // MARK: - Private

    /// Post a structured system message. `fallbackText` is the legacy English text stored on
    /// the row so older clients (or anything without the locale catalog) still has something
    /// to show; new clients prefer the localized template selected by `kind` + `args`.
    private func postSystemMessage(planId: String, fallbackText: String,
                                   kind: String, args: [String]) async throws {
        let msg = ChatMessage(
            planId: planId,
            senderId: "system",
            senderName: "System",
            text: fallbackText,
            isSystem: true,
            systemKind: kind,
            systemArgs: args
        )
        try await sendMessage(msg)
    }
}

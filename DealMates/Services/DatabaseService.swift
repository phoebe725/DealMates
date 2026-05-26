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
        print("[DEBUG] Fetching restaurants...")
        let results: [Restaurant] = try await client.from("restaurants").select().order("name", ascending: true).execute().value
        print("[DEBUG] Fetch returned \(results.count) restaurants")
        for r in results {
            print("[DEBUG] Restaurant: \(r.id) - \(r.name) - \(r.cuisine)")
        }
        return results
    }

    func fetchRestaurant(id: String) async throws -> Restaurant? {
        let results: [Restaurant] = try await client
            .from("restaurants").select().eq("id", value: id).limit(1).execute().value
        return results.first
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

    func createPlan(_ plan: Plan) async throws {
        try await client.from("plans").insert(plan).execute()
    }

    func updatePlan(_ plan: Plan) async throws {
        try await client.from("plans").update(plan).eq("id", value: plan.id).execute()
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
        try await postSystemMessage(planId: plan.id, text: "\(userName) joined the plan 🙌")
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
            try await postSystemMessage(planId: plan.id, text: "\(userName) left. \(nextUser.displayName) is now the organiser.")
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
        try await postSystemMessage(planId: plan.id, text: "\(userName) left the plan")
    }

    func removeMember(_ plan: Plan, targetUid: String, targetName: String, removerName: String) async throws {
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
        try await postSystemMessage(planId: plan.id, text: "\(removerName) removed \(targetName) from the plan.")
    }

    func fetchUser(id: String) async throws -> AppUser {
        try await client.from("users").select().eq("id", value: id).single().execute().value
    }

    func fetchUsers(ids: [String]) async throws -> [AppUser] {
        guard !ids.isEmpty else { return [] }
        return try await client.from("users").select().in("id", values: ids).execute().value
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

    private func postSystemMessage(planId: String, text: String) async throws {
        let msg = ChatMessage(
            planId: planId, senderId: "system",
            senderName: "System", text: text, isSystem: true
        )
        try await sendMessage(msg)
    }
}

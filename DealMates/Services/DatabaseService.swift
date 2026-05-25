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

    // MARK: - Messages

    func fetchMessages(planId: String) async throws -> [ChatMessage] {
        try await client.from("messages")
            .select()
            .eq("plan_id", value: planId)
            .order("timestamp", ascending: true)
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
                .channel("plans-\(restaurantId)")
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
                .channel("messages-\(planId)")
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

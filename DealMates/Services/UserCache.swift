import SwiftUI
import Combine

/// Single source of truth for the live `displayName` / `avatarURL` / etc. of every user
/// we've encountered. Views resolve their name/avatar through this cache instead of trusting
/// the denormalized `sender_name` / `creator_avatar_url` columns that were snapshotted at
/// write time. A global realtime listener on the `users` table (owned by `DatabaseService`)
/// pipes inserts and updates back into the cache, so historical chats, plan rows and DM
/// threads all reflect a user's current profile.
@MainActor
final class UserCache: ObservableObject {
    static let shared = UserCache()

    @Published var users: [String: AppUser] = [:]

    private var inFlight: Set<String> = []
    private var globalListenerTask: Task<Void, Never>?
    private let service = DatabaseService.shared

    // MARK: - Read

    func user(for id: String) -> AppUser? { users[id] }

    func name(for id: String, fallback: String = "") -> String {
        users[id]?.displayName ?? fallback
    }

    func avatarURL(for id: String, fallback: String? = nil) -> String? {
        users[id]?.avatarURL ?? fallback
    }

    // MARK: - Fetch

    /// Returns the cached user, or fetches it on the first call. Subsequent calls for the
    /// same id while a fetch is in flight wait briefly for the result instead of issuing a
    /// duplicate request.
    @discardableResult
    func ensure(id: String) async -> AppUser? {
        guard !id.isEmpty, id != "system" else { return nil }
        if let u = users[id] { return u }
        if inFlight.contains(id) {
            for _ in 0..<20 {
                try? await Task.sleep(nanoseconds: 50_000_000)
                if let u = users[id] { return u }
            }
            return users[id]
        }
        inFlight.insert(id)
        defer { inFlight.remove(id) }
        do {
            let u = try await service.fetchUser(id: id)
            users[u.id] = u
            return u
        } catch {
            print("[DEBUG] UserCache.fetch(\(id)) failed: \(error)")
            return nil
        }
    }

    /// Best-effort batch prefetch. Skips ids already in the cache.
    func prefetch(ids: [String]) async {
        let missing = Set(ids.filter { !$0.isEmpty && $0 != "system" && users[$0] == nil })
        guard !missing.isEmpty else { return }
        do {
            let fetched = try await service.fetchUsers(ids: Array(missing))
            for u in fetched { users[u.id] = u }
        } catch {
            print("[DEBUG] UserCache.prefetch failed: \(error)")
        }
    }

    /// Apply a known-good user (e.g., the signed-in user from AuthViewModel) without a fetch.
    func upsert(_ user: AppUser) { users[user.id] = user }

    // MARK: - Realtime

    /// Subscribe to all `users` table changes; idempotent.
    func startGlobalListener() {
        guard globalListenerTask == nil else { return }
        globalListenerTask = service.listenToAllUserUpdates { [weak self] user in
            self?.users[user.id] = user
        }
    }

    func stopGlobalListener() {
        globalListenerTask?.cancel()
        globalListenerTask = nil
    }
}

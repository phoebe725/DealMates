import Foundation
import UIKit
import UserNotifications
import Supabase

/// Glue between APNs device-token registration and the Supabase `device_tokens` table.
/// Currently dormant unless Apple Developer Program is enabled and Push Notifications
/// capability is attached in Xcode — kept here so it's ready when push goes live.
@MainActor
final class PushTokenService {
    static let shared = PushTokenService()

    private var pendingToken: String?
    private var currentUid: String = ""

    private init() {}

    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    func setCurrentUser(uid: String) {
        currentUid = uid
        if let t = pendingToken { Task { await save(token: t) } }
    }

    func didRegister(deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        if currentUid.isEmpty { pendingToken = hex }
        else { Task { await save(token: hex) } }
    }

    func didFailToRegister(error: Error) {
        print("[Push] register failed: \(error)")
    }

    /// Push the current notification_preference to every device token row for this user.
    func syncPreference() async {
        guard !currentUid.isEmpty else { return }
        let pref = UserDefaults.standard.string(forKey: "notification_preference") ?? "subscribed"
        struct Patch: Encodable { let notification_preference: String }
        _ = try? await SupabaseManager.shared.client
            .from("device_tokens")
            .update(Patch(notification_preference: pref))
            .eq("user_id", value: currentUid)
            .execute()
    }

    private func save(token: String) async {
        guard !currentUid.isEmpty else { return }
        let pref = UserDefaults.standard.string(forKey: "notification_preference") ?? "subscribed"
        struct Row: Encodable {
            let user_id: String
            let token: String
            let platform: String
            let notification_preference: String
        }
        let row = Row(user_id: currentUid, token: token, platform: "ios", notification_preference: pref)
        do {
            try await SupabaseManager.shared.client
                .from("device_tokens")
                .upsert(row, onConflict: "user_id,token")
                .execute()
            pendingToken = nil
        } catch {
            print("[Push] save token failed: \(error)")
        }
    }
}

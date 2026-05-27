import Foundation
import Supabase

// MARK: - AuthService

/// Manages Supabase Auth (Anonymous and Email/Password) and the `users` Postgres table.
final class AuthService {
    static let shared = AuthService()
    private var client: SupabaseClient { SupabaseManager.shared.client }

    private init() {}

    // MARK: Public

    func signInAnonymously() async throws -> AppUser {
        let session = try await client.auth.signInAnonymously()
        return try await ensureUserProfileExists(uid: session.user.id.uuidString.lowercased(), email: "")
    }

    /// Signs up a new user. Throws `AuthService.confirmationPending` if Supabase project requires
    /// email confirmation and the session hasn't been issued yet.
    func signUp(email: String, password: String, displayName: String, gender: Gender? = nil) async throws -> AppUser {
        let response = try await client.auth.signUp(email: email, password: password)
        let uid = response.user.id.uuidString.lowercased()
        let profile = try await ensureUserProfileExists(uid: uid, email: email, displayName: displayName)
        if let gender {
            try await updateGender(uid: uid, gender: gender)
        }
        if response.session == nil {
            // Email confirmation flow: project requires user to click confirm link before session is issued.
            throw NSError(
                domain: "DealMates.Auth",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Please check your email to confirm your account before signing in.", comment: "")]
            )
        }
        return profile
    }

    func updateGender(uid: String, gender: Gender) async throws {
        struct Patch: Encodable {
            let gender: String
            let updatedAt: Date
            enum CodingKeys: String, CodingKey {
                case gender
                case updatedAt = "updated_at"
            }
        }
        try await client.from("users")
            .update(Patch(gender: gender.rawValue, updatedAt: Date()))
            .eq("id", value: uid)
            .execute()
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        let response = try await client.auth.signIn(email: email, password: password)
        // Enforce email confirmation: refuse to keep an unconfirmed user signed in.
        if response.user.emailConfirmedAt == nil {
            try? await client.auth.signOut()
            throw NSError(
                domain: "DealMates.Auth",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Please check your email to confirm your account before signing in.", comment: "")]
            )
        }
        let uid = response.user.id.uuidString.lowercased()
        return try await ensureUserProfileExists(uid: uid, email: email)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func restoreSession() async throws -> AppUser? {
        // Returns the cached session without a network round-trip
        let session = try? await client.auth.session
        guard let uid = session?.user.id.uuidString.lowercased() else { return nil }
        let email = session?.user.email ?? ""
        return try? await ensureUserProfileExists(uid: uid, email: email)
    }

    func updateProfile(uid: String, displayName: String, bio: String, avatarURL: String?) async throws {
        struct Patch: Encodable {
            let displayName: String
            let bio: String
            let avatarURL: String?
            let updatedAt: Date
            enum CodingKeys: String, CodingKey {
                case displayName = "display_name"
                case bio
                case avatarURL = "avatar_url"
                case updatedAt = "updated_at"
            }
        }
        try await client.from("users")
            .update(Patch(displayName: displayName, bio: bio, avatarURL: avatarURL, updatedAt: Date()))
            .eq("id", value: uid)
            .execute()
    }

    /// Uploads JPEG data to the `avatars` Storage bucket under `{uid}.jpg`
    /// and returns the public URL with a cache-busting query param.
    func uploadAvatar(uid: String, jpegData: Data) async throws -> String {
        let path = "\(uid).jpg"
        _ = try await client.storage
            .from("avatars")
            .upload(
                path,
                data: jpegData,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )
        let publicURL = try client.storage.from("avatars").getPublicURL(path: path)
        // Cache-buster so AsyncImage refetches after re-upload (Storage URL is stable on upsert)
        return "\(publicURL.absoluteString)?t=\(Int(Date().timeIntervalSince1970))"
    }

    func blockUser(blockerUID: String, targetUID: String) async throws {
        // Fetch current list then append
        let user: AppUser = try await client
            .from("users").select().eq("id", value: blockerUID).single().execute().value
        var updated = user.blockedUsers
        guard !updated.contains(targetUID) else { return }
        updated.append(targetUID)

        struct Patch: Encodable {
            let blockedUsers: [String]
            enum CodingKeys: String, CodingKey {
                case blockedUsers = "blocked_users"
            }
        }
        try await client.from("users")
            .update(Patch(blockedUsers: updated))
            .eq("id", value: blockerUID)
            .execute()
    }

    func reportPlan(reporterUID: String, planId: String) async throws {
        // Update user's reportedPlans
        let user: AppUser = try await client
            .from("users").select().eq("id", value: reporterUID).single().execute().value
        var updatedPlans = user.reportedPlans
        guard !updatedPlans.contains(planId) else { return }
        updatedPlans.append(planId)

        struct UserPatch: Encodable {
            let reportedPlans: [String]
            enum CodingKeys: String, CodingKey {
                case reportedPlans = "reported_plans"
            }
        }
        try await client.from("users")
            .update(UserPatch(reportedPlans: updatedPlans))
            .eq("id", value: reporterUID)
            .execute()

        // Update plan's reportedBy
        let plan: Plan = try await client
            .from("plans").select().eq("id", value: planId).single().execute().value
        var reportedBy = plan.reportedBy
        guard !reportedBy.contains(reporterUID) else { return }
        reportedBy.append(reporterUID)

        struct PlanPatch: Encodable {
            let reportedBy: [String]
            enum CodingKeys: String, CodingKey {
                case reportedBy = "reported_by"
            }
        }
        try await client.from("plans")
            .update(PlanPatch(reportedBy: reportedBy))
            .eq("id", value: planId)
            .execute()
    }

    // MARK: Private

    private func ensureUserProfileExists(uid: String, email: String, displayName: String = "") async throws -> AppUser {
        let finalName = displayName.isEmpty ? "Diner\(Int.random(in: 100...999))" : displayName

        // First, check if the user profile already exists
        do {
            let existing: [AppUser] = try await client
                .from("users").select().eq("id", value: uid).limit(1).execute().value
            if let user = existing.first {
                print("[DEBUG] User profile already exists: id=\(uid)")
                return user
            }
        } catch {
            print("[DEBUG] Error checking existing user: \(error)")
            // Continue; might be a network error, or the user doesn't exist yet
        }

        // Try to upsert using primary key `id` (must not use email as conflict key)
        let newUser = AppUser(id: uid, email: email, displayName: finalName)
        do {
            print("[DEBUG] Upserting user by id: id=\(uid), email=\(email)")
            _ = try await client.from("users").upsert(newUser, onConflict: "id").execute()
            // Fetch canonical row
            let fetchedById: [AppUser] = try await client
                .from("users").select().eq("id", value: uid).limit(1).execute().value
            if let first = fetchedById.first { return first }
            return newUser
        } catch {
            print("[DEBUG] Upsert by id failed: \(error)")
            let msg = error.localizedDescription.lowercased()
            // If failure is due to duplicate email (another profile exists with same email),
            // fetch that profile and return it. Do NOT upsert by email.
            if msg.contains("users_email_key") || msg.contains("duplicate") || msg.contains("unique") {
                print("[DEBUG] Detected duplicate email constraint; fetching existing profile by email")
                let existingByEmail: [AppUser] = try await client
                    .from("users").select().eq("email", value: email).limit(1).execute().value
                if let first = existingByEmail.first { return first }
            }
            throw error
        }
    }
}

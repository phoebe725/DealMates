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

    /// Signs up a new user. Throws if the Supabase project requires email
    /// confirmation and the session hasn't been issued yet.
    ///
    /// If the caller is currently an anonymous guest (the default state — the
    /// app signs everyone in anonymously on launch), we *convert that account
    /// in place* via `auth.update` rather than calling `auth.signUp`. Signing
    /// up would mint a brand-new auth user and abandon the guest's row as an
    /// empty orphan; converting keeps the same uid, so any plans/messages the
    /// guest already created stay attached to them and no junk row is left
    /// behind.
    func signUp(email: String, password: String, displayName: String, gender: Gender? = nil, age: Int? = nil) async throws -> AppUser {
        let wasAnonymous = (try? await client.auth.session)?.user.isAnonymous ?? false

        let uid: String
        let needsConfirmation: Bool
        if wasAnonymous {
            let updated = try await client.auth.update(user: UserAttributes(email: email, password: password))
            uid = updated.id.uuidString.lowercased()
            // With "Confirm email" on, the new address is pending until the user
            // clicks the link; emailConfirmedAt stays nil and isAnonymous stays
            // true until then.
            needsConfirmation = updated.emailConfirmedAt == nil
        } else {
            let response = try await client.auth.signUp(email: email, password: password)
            uid = response.user.id.uuidString.lowercased()
            needsConfirmation = response.session == nil
        }

        // Make sure a row exists, then write the chosen name + email. Crucially,
        // keep `is_anonymous = true` while the email is still unconfirmed: the
        // app derives "signed in" from that flag (and mirrors the realtime row
        // into currentUser), so flipping it early would bounce an unconfirmed
        // user straight into the app. It only flips to false on a confirmed
        // sign-in (see `signIn`).
        _ = try await ensureUserProfileExists(uid: uid, email: email, displayName: displayName)
        try await promoteProfile(uid: uid, email: email, displayName: displayName, isAnonymous: needsConfirmation)
        if gender != nil || age != nil {
            try await updateDemographics(uid: uid, gender: gender, age: age)
        }

        let rows: [AppUser] = try await client
            .from("users").select().eq("id", value: uid).limit(1).execute().value
        let profile = rows.first ?? AppUser(id: uid, email: email, displayName: displayName)

        if needsConfirmation {
            throw NSError(
                domain: "DealMates.Auth",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: AppLocalization.string("Please check your email to confirm your account before signing in.")]
            )
        }
        return profile
    }

    /// Writes the chosen display name + email onto the profile row. `isAnonymous`
    /// is passed through deliberately: at sign-up time it stays `true` until the
    /// email is confirmed, so the app doesn't treat an unconfirmed account as
    /// signed in. `signIn` flips it to `false` once confirmation is verified.
    private func promoteProfile(uid: String, email: String, displayName: String, isAnonymous: Bool) async throws {
        struct Patch: Encodable {
            let email: String
            let displayName: String
            let isAnonymous: Bool
            let updatedAt: Date
            enum CodingKeys: String, CodingKey {
                case email
                case displayName = "display_name"
                case isAnonymous = "is_anonymous"
                case updatedAt = "updated_at"
            }
        }
        try await client.from("users")
            .update(Patch(email: email, displayName: displayName, isAnonymous: isAnonymous, updatedAt: Date()))
            .eq("id", value: uid)
            .execute()
    }

    /// Flips a row to a real (non-anonymous) account. Called from `signIn` after
    /// the email is confirmed.
    private func markAccountConfirmed(uid: String) async throws {
        struct Patch: Encodable {
            let isAnonymous: Bool
            let updatedAt: Date
            enum CodingKeys: String, CodingKey {
                case isAnonymous = "is_anonymous"
                case updatedAt = "updated_at"
            }
        }
        try await client.from("users")
            .update(Patch(isAnonymous: false, updatedAt: Date()))
            .eq("id", value: uid)
            .execute()
    }

    /// Resends the signup confirmation email for an account that exists but
    /// hasn't confirmed yet. Supabase intentionally succeeds even if the email
    /// is unknown (so callers can't probe which addresses are registered).
    func resendConfirmation(email: String) async throws {
        try await client.auth.resend(email: email, type: .signup)
    }

    /// Sends a password-reset email. The link returns to the web app, where the
    /// user sets a new password (one centralized reset flow). Supabase succeeds
    /// even for unknown addresses so callers can't probe which are registered.
    func sendPasswordReset(email: String) async throws {
        try await client.auth.resetPasswordForEmail(
            email,
            redirectTo: URL(string: "https://pintable-london.web.app")
        )
    }

    func updateGender(uid: String, gender: Gender) async throws {
        try await updateDemographics(uid: uid, gender: gender, age: nil)
    }

    func updateDemographics(uid: String, gender: Gender?, age: Int?) async throws {
        struct Patch: Encodable {
            let gender: String?
            let age: Int?
            let updatedAt: Date
            enum CodingKeys: String, CodingKey {
                case gender
                case age
                case updatedAt = "updated_at"
            }
        }
        try await client.from("users")
            .update(Patch(gender: gender?.rawValue, age: age, updatedAt: Date()))
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
                userInfo: [NSLocalizedDescriptionKey: AppLocalization.string("Please check your email to confirm your account before signing in.")]
            )
        }
        let uid = response.user.id.uuidString.lowercased()
        let existing = try await ensureUserProfileExists(uid: uid, email: email)
        // Email is confirmed at this point — promote the row to a real account
        // so the app treats them as signed in, then return the fresh row.
        try await markAccountConfirmed(uid: uid)
        let rows: [AppUser] = try await client
            .from("users").select().eq("id", value: uid).limit(1).execute().value
        return rows.first ?? existing
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func restoreSession() async throws -> AppUser? {
        // Returns the cached session without a network round-trip
        let session = try? await client.auth.session
        guard let user = session?.user else { return nil }
        let uid = user.id.uuidString.lowercased()
        let email = user.email ?? ""
        guard var profile = try? await ensureUserProfileExists(uid: uid, email: email) else { return nil }
        // The auth user — not the profile row — is the source of truth for
        // "is this a real, signed-in account". A converted-but-unconfirmed user
        // still carries an anonymous / unconfirmed session, so treat them as a
        // guest until the email is actually confirmed. Without this, a row whose
        // is_anonymous was flipped at sign-up time would let an unconfirmed user
        // straight in on the next launch.
        profile.isAnonymous = user.isAnonymous || user.emailConfirmedAt == nil
        return profile
    }

    /// Patches the user's profile and returns the updated row.
    ///
    /// `.select()` (without `.single()`) asks PostgREST to return the affected
    /// rows as an array. We then count them ourselves: a 0-row response means
    /// the update was blocked by RLS or matched no rows. That distinction
    /// lets us throw a human-readable error instead of the raw PGRST116
    /// "Cannot coerce the result to a single JSON object" that `.single()`
    /// surfaces in the same situation.
    @discardableResult
    func updateProfile(uid: String, displayName: String, bio: String, avatarURL: String?) async throws -> AppUser {
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
        let rows: [AppUser] = try await client.from("users")
            .update(Patch(displayName: displayName, bio: bio, avatarURL: avatarURL, updatedAt: Date()))
            .eq("id", value: uid)
            .select()
            .execute()
            .value
        if let user = rows.first { return user }

        // Update returned no rows. Re-fetch via a fresh GET so we can tell whether
        // the row exists at all — gives the user (and us in [DEBUG]) a clearer
        // signal about the actual failure mode.
        let existing: [AppUser] = try await client.from("users")
            .select()
            .eq("id", value: uid)
            .limit(1)
            .execute()
            .value
        if existing.first == nil {
            print("[DEBUG] updateProfile: no users row for uid=\(uid) — auth/profile mismatch?")
        } else {
            print("[DEBUG] updateProfile: RLS denied UPDATE for uid=\(uid). Check that auth.uid()::text matches the row id.")
        }
        throw NSError(
            domain: "DealMates.Auth",
            code: 1003,
            userInfo: [NSLocalizedDescriptionKey: AppLocalization.string(
                "Couldn't save my profile. Please sign out and back in, then try again."
            )]
        )
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
            // The unique-email constraint fires when a previous row used this
            // email under a different (now-stale) auth uid. Call the
            // consolidation RPC to re-point that row to the current auth uid
            // (and migrate any FK references) so this user is the canonical
            // owner of the row going forward. Without this fix, the next
            // profile update would silently RLS-deny because the row's id
            // wouldn't match `auth.uid()`.
            if msg.contains("users_email_key") || msg.contains("duplicate") || msg.contains("unique") {
                print("[DEBUG] Duplicate email — consolidating prior row into uid=\(uid)")
                struct ConsolidateParams: Encodable {
                    let target_email: String
                    let new_uid: String
                }
                do {
                    try await client.rpc(
                        "consolidate_user_by_email",
                        params: ConsolidateParams(target_email: email, new_uid: uid)
                    ).execute()
                } catch {
                    print("[DEBUG] consolidate_user_by_email RPC failed: \(error)")
                }
                let fetchedById: [AppUser] = try await client
                    .from("users").select().eq("id", value: uid).limit(1).execute().value
                if let first = fetchedById.first { return first }
            }
            throw error
        }
    }
}

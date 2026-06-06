import SwiftUI
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var currentUser: AppUser? {
        didSet {
            // Keep UserCache in sync with the signed-in user so every other view that resolves
            // names/avatars via the cache picks up profile edits immediately.
            if let currentUser { UserCache.shared.upsert(currentUser) }
        }
    }
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var isAuthenticated = false
    /// Set when a sign-up succeeds but the account still needs email
    /// confirmation. Drives the "Check your inbox" screen in `LoginView`.
    @Published var pendingConfirmationEmail: String?
    /// Transient success note (e.g. "email resent") shown on the inbox screen.
    @Published var infoMessage: String?

    private let service = AuthService.shared
    private var userCacheCancellable: AnyCancellable?

    init() {
        Task { await bootstrap() }
        // Mirror UserCache → currentUser for the signed-in user's id. This way
        // when the realtime listener brings in a fresh row for our own user
        // (server-side counter bumps, edits from another device, etc.) the
        // ProfileView updates in place — without us needing to re-fetch and
        // risking overwriting an in-flight local edit.
        userCacheCancellable = UserCache.shared.$users
            .receive(on: DispatchQueue.main)
            .sink { [weak self] users in
                guard let self,
                      let uid = self.currentUser?.id,
                      let cached = users[uid]
                else { return }
                // Skip if nothing actually changed — avoids a feedback loop
                // through `currentUser.didSet → UserCache.upsert → publisher`.
                if cached.updatedAt != self.currentUser?.updatedAt
                    || cached.displayName != self.currentUser?.displayName
                    || cached.bio != self.currentUser?.bio
                    || cached.avatarURL != self.currentUser?.avatarURL
                    || cached.attendedCount != self.currentUser?.attendedCount
                    || cached.attendanceRecordCount != self.currentUser?.attendanceRecordCount
                    || cached.hostedCount != self.currentUser?.hostedCount
                    || cached.gender != self.currentUser?.gender
                    || cached.age != self.currentUser?.age {
                    self.currentUser = cached
                }
            }
    }

    var uid: String          { currentUser?.id ?? "" }
    var displayName: String  { currentUser?.displayName ?? "Guest" }
    var email: String        { currentUser?.email ?? "" }
    var bio: String          { currentUser?.bio ?? "" }
    var avatarURL: String?   { currentUser?.avatarURL }
    var isSignedIn: Bool     { currentUser != nil && !currentUser!.isAnonymous }

    // MARK: - Bootstrap

    private func bootstrap() async {
        do {
            if let restored = try await service.restoreSession() {
                currentUser = restored
                isAuthenticated = !restored.isAnonymous
            } else {
                currentUser = try await service.signInAnonymously()
                isAuthenticated = false
            }
        } catch {
            currentUser = try? await service.signInAnonymously()
            isAuthenticated = false
        }
        isLoading = false
    }

    // MARK: - Auth Actions

    func signUp(email: String, password: String, displayName: String, gender: Gender? = nil, age: Int? = nil) async {
        errorMessage = nil
        infoMessage = nil
        do {
            let user = try await service.signUp(email: email, password: password, displayName: displayName, gender: gender, age: age)
            currentUser = user
            isAuthenticated = true
        } catch let error as NSError where error.domain == "DealMates.Auth" && error.code == 1001 {
            // Account created, but Supabase requires email confirmation before a
            // session is issued. Surface the dedicated "Check your inbox" flow
            // instead of a terse error banner.
            pendingConfirmationEmail = email
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Re-sends the confirmation email for the account awaiting verification.
    func resendConfirmation() async {
        guard let email = pendingConfirmationEmail else { return }
        errorMessage = nil
        infoMessage = nil
        do {
            try await service.resendConfirmation(email: email)
            infoMessage = AppLocalization.string("Email sent — check your inbox.")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Sends a password-reset email; the link opens the web app to set a new
    /// password (centralized reset flow). Surfaces a confirmation via infoMessage.
    func sendPasswordReset(email: String) async {
        errorMessage = nil
        infoMessage = nil
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = AppLocalization.string("Enter your email first to reset your password.")
            return
        }
        do {
            try await service.sendPasswordReset(email: trimmed)
            infoMessage = AppLocalization.string("Reset link sent — check your inbox.")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Leaves the "Check your inbox" screen and returns to the form.
    func cancelPendingConfirmation() {
        pendingConfirmationEmail = nil
        errorMessage = nil
        infoMessage = nil
    }

    /// Re-fetch the current user's row so counters and other server-mutated fields stay fresh.
    func refreshCurrentUser() async {
        guard !uid.isEmpty else { return }
        if let fresh = try? await DatabaseService.shared.fetchUser(id: uid) {
            currentUser = fresh
        }
    }

    func updateDemographics(gender: Gender?, age: Int?) async {
        guard !uid.isEmpty else { return }
        do {
            try await service.updateDemographics(uid: uid, gender: gender, age: age)
            if let gender { currentUser?.gender = gender }
            if let age { currentUser?.age = age }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        infoMessage = nil
        do {
            let user = try await service.signIn(email: email, password: password)
            currentUser = user
            isAuthenticated = true
            pendingConfirmationEmail = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        // The auth-level signOut comes first and we honour its outcome even
        // if the follow-up anonymous sign-in stumbles. That way the user
        // never gets stuck on the signed-in flow because a downstream call
        // threw — they'll see the signed-out hero and can sign in again.
        do {
            try await service.signOut()
            isAuthenticated = false
            currentUser = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        // Best-effort: re-establish an anonymous session so guest browsing
        // works. If this fails the user simply stays on the signed-out flow,
        // which is also a valid state.
        do {
            currentUser = try await service.signInAnonymously()
        } catch {
            print("[DEBUG] anonymous sign-in after signOut failed: \(error)")
        }
    }

    func updateProfile(displayName: String, bio: String, avatarURL: String? = nil) async {
        errorMessage = nil
        let finalAvatar = avatarURL ?? currentUser?.avatarURL
        do {
            // Take the server-confirmed row as truth. `service.updateProfile`
            // uses `.select().single()`, so this throws if 0 rows were updated
            // (e.g. RLS denied) — we'll never silently keep showing a local
            // edit that didn't actually persist.
            let updated = try await service.updateProfile(uid: uid, displayName: displayName, bio: bio, avatarURL: finalAvatar)
            currentUser = updated
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Uploads new avatar JPEG data and returns the public URL (with cache-buster).
    /// Caller is responsible for then calling `updateProfile` to persist the URL on the row.
    func uploadAvatar(jpegData: Data) async -> String? {
        do {
            return try await service.uploadAvatar(uid: uid, jpegData: jpegData)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - User Actions

    func blockUser(uid targetUID: String) async {
        try? await service.blockUser(blockerUID: uid, targetUID: targetUID)
        currentUser?.blockedUsers.append(targetUID)
    }

    func reportPlan(id planId: String) async {
        try? await service.reportPlan(reporterUID: uid, planId: planId)
        currentUser?.reportedPlans.append(planId)
    }

    func hasBlocked(uid targetUID: String) -> Bool {
        currentUser?.blockedUsers.contains(targetUID) ?? false
    }

    func hasReported(planId: String) -> Bool {
        currentUser?.reportedPlans.contains(planId) ?? false
    }
}

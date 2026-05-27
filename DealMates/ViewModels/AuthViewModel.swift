import SwiftUI
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var isAuthenticated = false

    private let service = AuthService.shared

    init() {
        Task { await bootstrap() }
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

    func signUp(email: String, password: String, displayName: String, gender: Gender? = nil) async {
        errorMessage = nil
        do {
            let user = try await service.signUp(email: email, password: password, displayName: displayName, gender: gender)
            currentUser = user
            isAuthenticated = true
        } catch {
            // Email confirmation pending is surfaced as an error message (not a fatal).
            errorMessage = error.localizedDescription
        }
    }

    func updateGender(_ gender: Gender) async {
        guard !uid.isEmpty else { return }
        do {
            try await service.updateGender(uid: uid, gender: gender)
            currentUser?.gender = gender
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        do {
            let user = try await service.signIn(email: email, password: password)
            currentUser = user
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        do {
            try await service.signOut()
            currentUser = try await service.signInAnonymously()
            isAuthenticated = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateProfile(displayName: String, bio: String, avatarURL: String? = nil) async {
        errorMessage = nil
        let finalAvatar = avatarURL ?? currentUser?.avatarURL
        do {
            try await service.updateProfile(uid: uid, displayName: displayName, bio: bio, avatarURL: finalAvatar)
            currentUser?.displayName = displayName
            currentUser?.bio = bio
            currentUser?.avatarURL = finalAvatar
            currentUser?.updatedAt = Date()
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

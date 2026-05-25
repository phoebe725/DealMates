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

    func signUp(email: String, password: String, displayName: String) async {
        errorMessage = nil
        do {
            let user = try await service.signUp(email: email, password: password, displayName: displayName)
            currentUser = user
            isAuthenticated = true
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

    func updateProfile(displayName: String, bio: String) async {
        errorMessage = nil
        do {
            try await service.updateProfile(uid: uid, displayName: displayName, bio: bio)
            currentUser?.displayName = displayName
            currentUser?.bio = bio
            currentUser?.updatedAt = Date()
        } catch {
            errorMessage = error.localizedDescription
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

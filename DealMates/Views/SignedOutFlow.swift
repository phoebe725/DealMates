import SwiftUI

/// Routes the signed-out experience. The user lands on `LaunchView`; tapping
/// either CTA pushes `LoginView` in the matching mode (sign up vs sign in).
/// Keeping the routing here means the App layer doesn't need to know about
/// modes, and `LaunchView` stays a presentation-only view.
struct SignedOutFlow: View {
    @State private var path: [Route] = []

    enum Route: Hashable { case login(signUp: Bool) }

    var body: some View {
        NavigationStack(path: $path) {
            LaunchView(
                onStart:  { path.append(.login(signUp: true))  },
                onSignIn: { path.append(.login(signUp: false)) }
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .login(let signUp):
                    LoginView(startInSignUp: signUp)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    SignedOutFlow()
        .environmentObject(AuthViewModel())
}

import SwiftUI

@main
struct DealMatesApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            if authViewModel.isLoading {
                SplashView()
            } else if !authViewModel.isSignedIn {
                LoginView()
                    .environmentObject(authViewModel)
            } else {
                ContentView()
                    .environmentObject(authViewModel)
            }
        }
    }
}

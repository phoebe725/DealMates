import SwiftUI

@main
struct DealMatesApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @AppStorage("preferredLanguageCode") private var languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
    @AppStorage("preferredRegionCode") private var regionCode: String = "GB"

    private var locale: Locale { Locale(identifier: "\(languageCode)_\(regionCode)") }

    var body: some Scene {
        WindowGroup {
            rootView
                .environment(\.locale, locale)
        }
    }

    @ViewBuilder
    private var rootView: some View {
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

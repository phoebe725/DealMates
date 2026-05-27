import SwiftUI
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in
            PushTokenService.shared.didRegister(deviceToken: deviceToken)
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in
            PushTokenService.shared.didFailToRegister(error: error)
        }
    }
}

@main
struct DealMatesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authViewModel = AuthViewModel()
    @AppStorage("preferredLanguageCode") private var languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
    @AppStorage("preferredRegionCode") private var regionCode: String = "GB"

    init() {
        // Bundle.main reads AppleLanguages at string-resolution time. Seed it from the in-app
        // picker before SwiftUI builds the first frame so Text(...) resolves to the right
        // language entries in the String Catalog from launch.
        let lang = UserDefaults.standard.string(forKey: "preferredLanguageCode")
            ?? Locale.current.language.languageCode?.identifier ?? "en"
        UserDefaults.standard.set([lang], forKey: "AppleLanguages")
    }

    private var locale: Locale { Locale(identifier: "\(languageCode)_\(regionCode)") }

    var body: some Scene {
        WindowGroup {
            rootView
                .environment(\.locale, locale)
                // Force the entire view tree to rebuild when the user changes language —
                // AppleLanguages alone updates Bundle.main but doesn't refresh cached Text views.
                .id(languageCode)
                .task {
                    // Mirror all `users` table changes into the cache so name/avatar updates
                    // propagate everywhere (historical chats, plan rows, DM headers).
                    UserCache.shared.startGlobalListener()
                    // Preload restaurants once so plan rows can resolve the localized name
                    // even when navigated to via push / deep link (no DiscoverView load).
                    await RestaurantCache.shared.loadAll()
                }
                .onChange(of: languageCode) { _, newLang in
                    UserDefaults.standard.set([newLang], forKey: "AppleLanguages")
                }
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

import SwiftUI
import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Become the notification center's delegate so we can override the
        // default "don't show banners while app is foregrounded" behaviour.
        // Without this, member-joined / raft-ready alerts only surface when
        // the app is backgrounded, which felt to the user like "in-app
        // notifications aren't working at all".
        UNUserNotificationCenter.current().delegate = self
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

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when a notification arrives while the app is in the foreground.
    /// Default behaviour is to suppress the banner — we explicitly ask iOS to
    /// show the banner + play the sound so the user sees the alert in-app.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}

@main
struct DealMatesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authViewModel = AuthViewModel()
    // Owned at the App layer so it survives the `.id(languageCode)` rebuild of
    // the root view tree. The user keeps whichever tab they were on when they
    // switch language.
    @StateObject private var tabState = TabStateStore()
    @AppStorage("preferredLanguageCode") private var languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
    @AppStorage("preferredRegionCode") private var regionCode: String = "GB"

    init() {
        // Register brand fonts (Instrument Serif + Inter) before SwiftUI tries to resolve any
        // `Font.custom(...)` calls — otherwise the first frame paints with system fallbacks.
        FontRegistry.registerAll()

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
            SignedOutFlow()
                .environmentObject(authViewModel)
        } else {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(tabState)
        }
    }
}

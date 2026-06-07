import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var tabState: TabStateStore
    @ObservedObject private var unread = UnreadManager.shared
    @AppStorage("preferredLanguageCode") private var languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
    @AppStorage("preferredRegionCode") private var regionCode: String = "GB"

    private var locale: Locale { Locale(identifier: "\(languageCode)_\(regionCode)") }

    private func wrap<V: View>(_ view: V) -> AnyView {
        AnyView(view.environmentObject(authViewModel).environment(\.locale, locale))
    }

    var body: some View {
        NoAnimationTabBar(
            selectedIndex: $tabState.selectedTab,
            tabs: [
                .init(
                    view: wrap(DiscoverView()),
                    title: AppLocalization.string("Discover", comment: ""),
                    systemImage: "fork.knife",
                    badge: nil
                ),
                .init(
                    view: wrap(MyPlansView()),
                    title: AppLocalization.string("My Plans", comment: ""),
                    systemImage: "calendar",
                    // Unread plan *actions* — someone joined / left / was removed
                    // in one of your plans. (Active / ready-to-go counts live on
                    // the segmented control inside the tab.) Clears once you open
                    // that plan's chat.
                    badge: unread.unreadActionCount > 0
                        ? "\(unread.unreadActionCount)"
                        : nil
                ),
                .init(
                    view: wrap(MessagesView()),
                    title: AppLocalization.string("Messages", comment: ""),
                    systemImage: "bubble.left.and.bubble.right.fill",
                    badge: unread.totalUnread > 0 ? "\(unread.totalUnread)" : nil
                ),
                .init(
                    view: wrap(ProfileView()),
                    title: AppLocalization.string("Profile", comment: ""),
                    systemImage: "person.fill",
                    badge: nil
                )
            ],
            tintColor: UIColor(Color.pinClay)
        )
        .ignoresSafeArea()
        .task {
            AnalyticsService.shared.setUser(authViewModel.uid)
            AnalyticsService.shared.startSession() // auth is ready by the time ContentView renders

            await unread.refresh(currentUid: authViewModel.uid)
            // Realtime badge updates — message inserts, DM inserts, plan changes.
            unread.startListening(currentUid: authViewModel.uid)
            await NotificationManager.shared.requestAuthorization()
            PushTokenService.shared.setCurrentUser(uid: authViewModel.uid)
            await SubscriptionsViewModel.shared.load(currentUid: authViewModel.uid)
            NotificationManager.shared.startListening(currentUid: authViewModel.uid)
        }
        .onChange(of: authViewModel.uid) { _, newUid in
            AnalyticsService.shared.setUser(newUid)
            Task {
                await unread.refresh(currentUid: newUid)
                unread.startListening(currentUid: newUid)
                PushTokenService.shared.setCurrentUser(uid: newUid)
                await SubscriptionsViewModel.shared.load(currentUid: newUid)
                NotificationManager.shared.startListening(currentUid: newUid)
            }
        }
    }
}

// MARK: - SplashView
//
// Shown while `AuthViewModel.bootstrap()` figures out whether we have a session.
// Intentionally quiet — no copy beyond the wordmark — because it appears for a
// few hundred ms at most. The mascot + tagline live on `LaunchView` for the
// signed-out case where the user lingers.

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.pinCream.ignoresSafeArea()
            VStack(spacing: 20) {
                PintableWordmark(size: 44)
                ProgressView()
                    .tint(Color.pinInkMuted)
                    .scaleEffect(0.9)
            }
        }
    }
}

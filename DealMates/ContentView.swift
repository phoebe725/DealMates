import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var unread = UnreadManager.shared
    @State private var selectedTab: Int = 0
    @AppStorage("preferredLanguageCode") private var languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
    @AppStorage("preferredRegionCode") private var regionCode: String = "GB"

    private var locale: Locale { Locale(identifier: "\(languageCode)_\(regionCode)") }

    private func wrap<V: View>(_ view: V) -> AnyView {
        AnyView(view.environmentObject(authViewModel).environment(\.locale, locale))
    }

    var body: some View {
        NoAnimationTabBar(
            selectedIndex: $selectedTab,
            tabs: [
                .init(
                    view: wrap(DiscoverView()),
                    title: NSLocalizedString("Discover", comment: ""),
                    systemImage: "fork.knife",
                    badge: nil
                ),
                .init(
                    view: wrap(MyPlansView()),
                    title: NSLocalizedString("My Plans", comment: ""),
                    systemImage: "calendar",
                    badge: nil
                ),
                .init(
                    view: wrap(MessagesView()),
                    title: NSLocalizedString("Messages", comment: ""),
                    systemImage: "bubble.left.and.bubble.right.fill",
                    badge: unread.totalUnread > 0 ? "\(unread.totalUnread)" : nil
                ),
                .init(
                    view: wrap(ProfileView()),
                    title: NSLocalizedString("Profile", comment: ""),
                    systemImage: "person.fill",
                    badge: nil
                )
            ],
            tintColor: .systemOrange
        )
        .ignoresSafeArea()
        .task {
            await unread.refresh(currentUid: authViewModel.uid)
            await NotificationManager.shared.requestAuthorization()
            PushTokenService.shared.setCurrentUser(uid: authViewModel.uid)
            await SubscriptionsViewModel.shared.load(currentUid: authViewModel.uid)
            NotificationManager.shared.startListening(currentUid: authViewModel.uid)
        }
        .onChange(of: authViewModel.uid) { _, newUid in
            Task {
                await unread.refresh(currentUid: newUid)
                PushTokenService.shared.setCurrentUser(uid: newUid)
                await SubscriptionsViewModel.shared.load(currentUid: newUid)
                NotificationManager.shared.startListening(currentUid: newUid)
            }
        }
    }
}

// MARK: - SplashView

struct SplashView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 90))
                .foregroundColor(.orange)
            Text("DealMates")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            ProgressView()
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

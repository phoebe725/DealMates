import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        TabView {
            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: "fork.knife")
                }

            MyPlansView()
                .tabItem {
                    Label("My Plans", systemImage: "calendar")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .tint(.orange)
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

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("preferredLanguageCode") private var languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
    @AppStorage("preferredRegionCode") private var regionCode: String = "GB"
    @AppStorage("notification_preference") private var notificationPreference: String = NotificationPreference.subscribed.rawValue

    private let languages: [(code: String, label: String)] = [
        ("en", "English"),
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁體中文")
    ]

    private let regions: [(code: String, label: LocalizedStringKey)] = [
        ("GB", "United Kingdom")
    ]

    var body: some View {
        ZStack {
            Color.pinCream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section("Language") {
                        Picker("Language", selection: $languageCode) {
                            ForEach(languages, id: \.code) { entry in
                                Text(entry.label).tag(entry.code)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.pinClay)
                    }

                    section("Region") {
                        Picker("Region", selection: $regionCode) {
                            ForEach(regions, id: \.code) { entry in
                                Text(entry.label).tag(entry.code)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.pinClay)
                    }

                    section("Notifications") {
                        Picker("New pins", selection: $notificationPreference) {
                            ForEach(NotificationPreference.allCases) { pref in
                                Text(LocalizedStringKey(pref.label)).tag(pref.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.pinClay)
                        .onChange(of: notificationPreference) { _, _ in
                            Task { await PushTokenService.shared.syncPreference() }
                        }
                    }

                    if authViewModel.isSignedIn {
                        signOutButton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Settings")
                    .font(.pinBody(15, weight: .medium))
                    .foregroundStyle(Color.pinInk)
            }
        }
        .toolbarBackground(Color.pinCream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .animation(.none, value: languageCode)
        .animation(.none, value: regionCode)
        .transaction { $0.animation = nil }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            PinSectionHeader(title: title)
            HStack {
                content()
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.pinShell)
            )
        }
    }

    private var signOutButton: some View {
        Button {
            Task { await authViewModel.signOut() }
        } label: {
            HStack {
                Image(systemName: "arrow.left.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.pinClayDeep)
                Text("Sign out")
                    .font(.pinButton(14))
                    .foregroundStyle(Color.pinClayDeep)
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.pinClay.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }
}

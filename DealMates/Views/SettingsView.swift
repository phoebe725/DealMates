import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("preferredLanguageCode") private var languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
    @AppStorage("preferredRegionCode") private var regionCode: String = "GB"

    private let languages: [(code: String, label: String)] = [
        ("en", "English"),
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁體中文")
    ]

    private let regions: [(code: String, label: LocalizedStringKey)] = [
        ("GB", "United Kingdom")
    ]

    var body: some View {
        List {
            Section("Language") {
                Picker("Language", selection: $languageCode) {
                    ForEach(languages, id: \.code) { entry in
                        Text(entry.label).tag(entry.code)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Region") {
                Picker("Region", selection: $regionCode) {
                    ForEach(regions, id: \.code) { entry in
                        Text(entry.label).tag(entry.code)
                    }
                }
                .pickerStyle(.menu)
            }

            if authViewModel.isSignedIn {
                Section {
                    Button(role: .destructive) {
                        Task { await authViewModel.signOut() }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.left.circle.fill")
                            Text("Sign Out")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.none, value: languageCode)
        .animation(.none, value: regionCode)
        .transaction { $0.animation = nil }
    }
}

import SwiftUI

struct UserProfileSheetTarget: Identifiable, Hashable {
    let id: String
}

struct UserProfileView: View {
    let userId: String
    @Environment(\.dismiss) private var dismiss
    @State private var user: AppUser?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let user {
                    profileContent(user)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text(errorMessage ?? "Could not load profile")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    private func profileContent(_ user: AppUser) -> some View {
        List {
            Section {
                HStack(spacing: 16) {
                    AvatarImage(
                        urlString: user.avatarURL,
                        name: user.displayName,
                        size: 72,
                        fontSize: 32
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.displayName)
                            .font(.title3.bold())
                        if let gender = user.gender {
                            HStack(spacing: 4) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.pink)
                                Text(LocalizedStringKey(gender.label))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
            }

            if !user.bio.isEmpty {
                Section("Bio") {
                    Text(user.bio)
                        .font(.subheadline)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func load() async {
        do {
            user = try await DatabaseService.shared.fetchUser(id: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

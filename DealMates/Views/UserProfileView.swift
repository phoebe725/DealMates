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
    @State private var listenerTask: Task<Void, Never>?

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
        .onAppear {
            Task { await load() }
            startListening()
        }
        .onDisappear { stopListening() }
    }

    private func profileContent(_ user: AppUser) -> some View {
        List {
            Section {
                ProfileHeaderView(user: user, avatarSize: 72, avatarFontSize: 32)
            }

            if !user.bio.isEmpty {
                Section("Bio") {
                    Text(user.bio)
                        .font(.subheadline)
                }
            }

            Section("Credits") {
                HStack {
                    Label("Attendance rate", systemImage: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        if let rate = user.attendanceRate {
                            Text("\(Int(rate * 100))%")
                                .font(.headline.monospacedDigit())
                            Text("\(user.attendedCount) / \(user.attendanceRecordCount)")
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(.secondary)
                        } else {
                            Text("—")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                HStack {
                    Label("Hosted", systemImage: "crown.fill")
                        .foregroundColor(.orange)
                    Spacer()
                    Text("\(user.hostedCount)")
                        .font(.headline.monospacedDigit())
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func load() async {
        do {
            user = try await DatabaseService.shared.fetchUser(id: userId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func startListening() {
        stopListening()
        listenerTask = DatabaseService.shared.listenToUser(uid: userId) {
            await load()
        }
    }

    private func stopListening() {
        listenerTask?.cancel()
        listenerTask = nil
    }
}

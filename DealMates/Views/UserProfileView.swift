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
            ZStack {
                Color.pinCream.ignoresSafeArea()

                Group {
                    if isLoading {
                        ProgressView().tint(Color.pinInkMuted)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let user {
                        profileContent(user)
                    } else {
                        // `LocalizedStringKey(_:)` looks up the value in the catalog if a key
                        // matches (so the default copy translates) and falls back to verbatim
                        // when it doesn't (so the runtime Supabase error renders as-is).
                        PinEmptyState(
                            title: "Profile unavailable",
                            message: LocalizedStringKey(errorMessage ?? "Couldn't load this puffin's profile."),
                            systemImage: "person.crop.circle.badge.exclamationmark"
                        )
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Profile")
                        .font(.pinBody(15, weight: .medium))
                        .foregroundStyle(Color.pinInk)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.pinButton(15))
                        .foregroundStyle(Color.pinClay)
                }
            }
            .toolbarBackground(Color.pinCream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            Task { await load() }
            startListening()
        }
        .onDisappear { stopListening() }
    }

    private func profileContent(_ user: AppUser) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ProfileHeaderView(user: user)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.pinShell)
                    )

                if !user.bio.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        PinSectionHeader(title: "Bio")
                        Text(user.bio)
                            .font(.pinBody(14))
                            .foregroundStyle(Color.pinInk)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.pinShell)
                            )
                    }
                }

                creditsSection(user)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    private func creditsSection(_ user: AppUser) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            PinSectionHeader(title: "Credit")
            VStack(spacing: 0) {
                creditRow(
                    icon: "checkmark.seal.fill",
                    tint: .pinSageDeep,
                    label: "Attendance rate",
                    trailing: {
                        VStack(alignment: .trailing, spacing: 2) {
                            if let rate = user.attendanceRate {
                                Text("\(Int(rate * 100))%")
                                    .font(.pinBody(15, weight: .medium).monospacedDigit())
                                    .foregroundStyle(Color.pinInk)
                                Text("\(user.attendedCount) / \(user.attendanceRecordCount)")
                                    .font(.pinSubtitle(11).monospacedDigit())
                                    .foregroundStyle(Color.pinInkMuted)
                            } else {
                                Text("—")
                                    .font(.pinBody(15, weight: .medium))
                                    .foregroundStyle(Color.pinInkMuted)
                            }
                        }
                    }
                )
                Divider().background(Color.pinFog).padding(.leading, 50)
                creditRow(
                    icon: "crown.fill",
                    tint: .pinClay,
                    label: "Hosted",
                    trailing: {
                        Text("\(user.hostedCount)")
                            .font(.pinBody(15, weight: .medium).monospacedDigit())
                            .foregroundStyle(Color.pinInk)
                    }
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.pinShell)
            )
        }
    }

    private func creditRow<Trailing: View>(icon: String, tint: Color, label: LocalizedStringKey, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(Circle().fill(tint.opacity(0.18)))
            Text(label)
                .font(.pinBody(14))
                .foregroundStyle(Color.pinInk)
            Spacer()
            trailing()
        }
        .padding(14)
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

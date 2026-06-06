import SwiftUI
import PhotosUI

// MARK: - ProfileView

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showEditSheet = false
    @State private var showAdmin = false

    /// Founder gate for the hidden admin entry (long-press the wordmark).
    private var isFounder: Bool {
        (authViewModel.currentUser?.email ?? "").lowercased()
            == Config.founderEmail.lowercased()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pinCream.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                            .padding(.horizontal, 20)
                            .padding(.top, 12)

                        profileCard
                            .padding(.horizontal, 20)

                        if !authViewModel.bio.isEmpty {
                            bioCard
                                .padding(.horizontal, 20)
                        }

                        creditsSection
                            .padding(.horizontal, 20)

                        accountSection
                            .padding(.horizontal, 20)

                        settingsLink
                            .padding(.horizontal, 20)

                        howItWorksSection
                            .padding(.horizontal, 20)

                        aboutSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 32)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            // No `refreshCurrentUser` on appear — the realtime listener on
            // `users` keeps UserCache fresh, and AuthViewModel observes the
            // cache for its own uid. Re-fetching on every appear could silently
            // overwrite a fresh local edit while the write was still in flight.
            .sheet(isPresented: $showEditSheet) {
                ProfileEditView(isPresented: $showEditSheet)
                    .environmentObject(authViewModel)
            }
            .sheet(isPresented: $showAdmin) { AdminView() }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Long-pressing the wordmark opens the founder admin console — a
            // no-op for everyone but the founder account.
            PintableWordmark(size: 18)
                .onLongPressGesture(minimumDuration: 0.6) {
                    if isFounder { showAdmin = true }
                }
            Text("Me.")
                .font(.pinAccent(40))
                .foregroundStyle(Color.pinClayDeep)
            Text("How my mates see me on Pintable.")
                .font(.pinSubtitle(13))
                .foregroundStyle(Color.pinInkMuted)
        }
    }

    // MARK: - Profile card

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let user = authViewModel.currentUser {
                ProfileHeaderView(user: user)
            } else {
                HStack(spacing: 16) {
                    AvatarImage(
                        urlString: authViewModel.avatarURL,
                        name: authViewModel.displayName,
                        size: 72,
                        fontSize: 32
                    )
                    Text(authViewModel.displayName)
                        .font(.pinBody(20, weight: .medium))
                        .foregroundStyle(Color.pinInk)
                    Spacer()
                }
            }

            if authViewModel.isSignedIn {
                Button {
                    showEditSheet = true
                } label: {
                    Label("Edit profile", systemImage: "pencil")
                        .font(.pinButton(14))
                        .foregroundStyle(Color.pinClayDeep)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.pinClay.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink {
                    LoginView()
                } label: {
                    Label("Sign in or create account", systemImage: "person.crop.circle.badge.plus")
                        .font(.pinButton(14))
                        .foregroundStyle(Color.pinCream)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.pinClay)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.pinShell)
        )
    }

    // MARK: - Bio

    private var bioCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            PinSectionHeader(title: "Bio")
            Text(authViewModel.bio)
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

    // MARK: - Credits

    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            PinSectionHeader(title: "Credit")
            VStack(spacing: 0) {
                creditRow(
                    icon: "checkmark.seal.fill",
                    tint: .pinSageDeep,
                    label: "Attendance rate",
                    trailing: {
                        VStack(alignment: .trailing, spacing: 2) {
                            if let rate = authViewModel.currentUser?.attendanceRate {
                                Text("\(Int(rate * 100))%")
                                    .font(.pinBody(15, weight: .medium).monospacedDigit())
                                    .foregroundStyle(Color.pinInk)
                                let attended = authViewModel.currentUser?.attendedCount ?? 0
                                let total = authViewModel.currentUser?.attendanceRecordCount ?? 0
                                Text("\(attended) / \(total)")
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
                        Text("\(authViewModel.currentUser?.hostedCount ?? 0)")
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

    // MARK: - Account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            PinSectionHeader(title: "Account")
            VStack(spacing: 0) {
                row(
                    label: "Mode",
                    valueKey: authViewModel.isSignedIn ? "Registered" : "Guest"
                )
                if authViewModel.isSignedIn {
                    Divider().background(Color.pinFog)
                    row(label: "Email", value: authViewModel.email)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.pinShell)
            )
        }
    }

    /// `label` is a fixed UI label (localised); `value` is runtime data
    /// (email, mode label, version string) so it renders verbatim — calling
    /// sites that pass a localised constant for `value` should use the
    /// `row(label:valueKey:)` overload below.
    private func row(label: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(label)
                .font(.pinBody(14))
                .foregroundStyle(Color.pinInk)
            Spacer()
            Text(value)
                .font(.pinSubtitle(13))
                .foregroundStyle(Color.pinInkMuted)
                .lineLimit(1)
        }
        .padding(14)
    }

    /// Overload for cases where the value is a fixed localised string
    /// ("Registered" / "Guest", "PinTable", "1.0.0").
    private func row(label: LocalizedStringKey, valueKey: LocalizedStringKey) -> some View {
        HStack {
            Text(label)
                .font(.pinBody(14))
                .foregroundStyle(Color.pinInk)
            Spacer()
            Text(valueKey)
                .font(.pinSubtitle(13))
                .foregroundStyle(Color.pinInkMuted)
                .lineLimit(1)
        }
        .padding(14)
    }

    // MARK: - Settings link

    private var settingsLink: some View {
        NavigationLink {
            SettingsView().environmentObject(authViewModel)
        } label: {
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.pinInk)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.pinFog))
                Text("Settings")
                    .font(.pinBody(14))
                    .foregroundStyle(Color.pinInk)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.pinInkMuted)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.pinShell)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - How it works

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            PinSectionHeader(title: "How PinTable works")
            VStack(alignment: .leading, spacing: 12) {
                howRow(number: "1", text: "Browse restaurants and see who's already planning to dine.")
                howRow(number: "2", text: "Pin a plan — set time, group size, and goal.")
                howRow(number: "3", text: "Chat in real-time with your mates before heading over.")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.pinShell)
            )
        }
    }

    private func howRow(number: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // `number` is a digit ("1", "2", "3") — render verbatim.
            Text(number)
                .font(.pinAccent(20))
                .foregroundStyle(Color.pinClayDeep)
                .frame(width: 24, alignment: .leading)
            Text(text)
                .font(.pinBody(13))
                .foregroundStyle(Color.pinInk)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            PinSectionHeader(title: "About")
            VStack(spacing: 0) {
                row(label: "App", value: "PinTable")
                Divider().background(Color.pinFog)
                row(label: "Version", value: "1.0.0")
            }
            // "PinTable" stays as the brand verbatim, "1.0.0" is data — both
            // correctly use the String overload above.
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.pinShell)
            )
        }
    }
}

// MARK: - ProfileEditView

struct ProfileEditView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var isPresented: Bool
    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var gender: Gender = .female
    @State private var ageText: String = ""
    @State private var isSaving = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var pendingAvatarData: Data?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pinCream.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        photoSection
                        fieldsSection
                        if let error = authViewModel.errorMessage {
                            errorBanner(error)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 64)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Edit profile")
                        .font(.pinBody(15, weight: .medium))
                        .foregroundStyle(Color.pinInk)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .font(.pinButton(15))
                        .foregroundStyle(Color.pinInk)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(Color.pinClay)
                        } else {
                            Text("Save")
                                .font(.pinButton(15))
                                .foregroundStyle(Color.pinClay)
                        }
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .toolbarBackground(Color.pinCream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                // Clear any stale error from a prior operation (e.g., a failed
                // anonymous re-sign-in after signOut) so the user lands on a
                // fresh edit form instead of seeing an unrelated banner.
                authViewModel.errorMessage = nil
                displayName = authViewModel.displayName
                bio = authViewModel.bio
                gender = authViewModel.currentUser?.gender ?? .female
                if let age = authViewModel.currentUser?.age { ageText = String(age) } else { ageText = "" }
            }
            .onChange(of: pickedItem) { _, newItem in
                Task {
                    guard let newItem else { return }
                    if let raw = try? await newItem.loadTransferable(type: Data.self) {
                        pendingAvatarData = AvatarImage.compressedJPEG(from: raw)
                    }
                }
            }
        }
    }

    // MARK: - Photo

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PinSectionHeader(title: "Photo")
            HStack(spacing: 16) {
                Group {
                    if let data = pendingAvatarData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(Circle())
                    } else {
                        AvatarImage(
                            urlString: authViewModel.avatarURL,
                            name: displayName.isEmpty ? authViewModel.displayName : displayName,
                            size: 72,
                            fontSize: 32
                        )
                    }
                }
                PhotosPicker(selection: $pickedItem, matching: .images, photoLibrary: .shared()) {
                    Label("Choose photo", systemImage: "photo.on.rectangle")
                        .font(.pinButton(14))
                        .foregroundStyle(Color.pinClayDeep)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.pinClay.opacity(0.12))
                        )
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.pinShell)
            )
        }
    }

    // MARK: - Fields

    private var fieldsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            field("Display name") {
                TextField("Enter your name", text: $displayName)
                    .pinTextField()
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Gender")
                PinSegmentedPicker(
                    options: [(value: Gender.female, label: "Female"),
                              (value: Gender.male, label: "Male")],
                    selection: $gender
                )
            }

            field("Age (optional)") {
                TextField("27", text: $ageText)
                    .keyboardType(.numberPad)
                    .pinTextField()
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Bio")
                TextField("Tell others a bit about yourself", text: $bio, axis: .vertical)
                    .lineLimit(1...4)
                    .onChange(of: bio) { _, newValue in
                        if newValue.count > 150 { bio = String(newValue.prefix(150)) }
                    }
                    .pinTextField()
                Text("\(bio.count) / 150")
                    .font(.pinSubtitle(11))
                    .foregroundStyle(Color.pinInkMuted)
            }
        }
    }

    private func field<Content: View>(_ label: LocalizedStringKey, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(label)
            content()
        }
    }

    private func fieldLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.pinBody(14, weight: .medium))
            .foregroundStyle(Color.pinInk)
    }

    /// Runtime error message from Supabase; render verbatim.
    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Color.pinClayDeep)
            Text(message)
                .font(.pinBody(13))
                .foregroundStyle(Color.pinInk)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.pinClay.opacity(0.12))
        )
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        var newURL: String? = nil
        if let data = pendingAvatarData {
            newURL = await authViewModel.uploadAvatar(jpegData: data)
            if newURL == nil { return }
        }
        await authViewModel.updateProfile(displayName: displayName, bio: bio, avatarURL: newURL)
        let parsedAge = Int(ageText.trimmingCharacters(in: .whitespaces))
        let genderChanged = authViewModel.currentUser?.gender != gender
        let ageChanged    = authViewModel.currentUser?.age != parsedAge
        if genderChanged || ageChanged {
            await authViewModel.updateDemographics(
                gender: genderChanged ? gender : nil,
                age: ageChanged ? parsedAge : nil
            )
        }
        if authViewModel.errorMessage == nil {
            isPresented = false
        }
    }
}

// MARK: - Text field modifier (mirrors LoginView)

private struct PinTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.pinBody(15))
            .foregroundStyle(Color.pinInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.pinShell)
            )
            .tint(Color.pinClay)
    }
}

private extension View {
    func pinTextField() -> some View { modifier(PinTextFieldModifier()) }
}

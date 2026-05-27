import SwiftUI
import PhotosUI

// MARK: - ProfileView

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showEditSheet = false

    var body: some View {
        NavigationStack {
            List {
                // Public preview — matches what others see when they tap this user's profile pic
                // (avatar + name + gender + Age chip + bio). Credits/account info live below and
                // are only visible to the owner.
                Section {
                    if let user = authViewModel.currentUser {
                        ProfileHeaderView(user: user, avatarSize: 72, avatarFontSize: 32)
                    } else {
                        HStack(spacing: 16) {
                            AvatarImage(
                                urlString: authViewModel.avatarURL,
                                name: authViewModel.displayName,
                                size: 72,
                                fontSize: 32
                            )
                            Text(authViewModel.displayName)
                                .font(.title3.bold())
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }

                    if !authViewModel.bio.isEmpty {
                        Text(authViewModel.bio)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if authViewModel.isSignedIn {
                        Button {
                            showEditSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "pencil.circle.fill")
                                Text("Edit Profile")
                            }
                            .foregroundColor(.orange)
                        }
                    } else {
                        NavigationLink(destination: LoginView()) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.plus")
                                Text("Sign In or Create Account")
                            }
                            .foregroundColor(.orange)
                        }
                    }
                }

                // Credits (attendance rate + hosted count)
                Section("Credits") {
                    HStack {
                        Label("Attendance rate", systemImage: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            if let rate = authViewModel.currentUser?.attendanceRate {
                                Text("\(Int(rate * 100))%")
                                    .font(.headline.monospacedDigit())
                                let attended = authViewModel.currentUser?.attendedCount ?? 0
                                let total = authViewModel.currentUser?.attendanceRecordCount ?? 0
                                Text("\(attended) / \(total)")
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
                        Text("\(authViewModel.currentUser?.hostedCount ?? 0)")
                            .font(.headline.monospacedDigit())
                    }
                }

                // Account status
                Section("Account Status") {
                    LabeledContent("Mode", value: authViewModel.isSignedIn ? "Registered" : "Guest (Anonymous)")
                    if authViewModel.isSignedIn {
                        LabeledContent("Email", value: authViewModel.email)
                    }
                }

                // Settings entry (Sign Out, Language, Region live here)
                Section {
                    NavigationLink(destination: SettingsView().environmentObject(authViewModel)) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text("Settings")
                        }
                    }
                }

                // App info
                Section("About") {
                    LabeledContent("App", value: "DealMates")
                    LabeledContent("Version", value: "1.0.0")
                }

                // Info
                Section("How it works") {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "1.circle.fill").foregroundColor(.orange)
                        Text("Browse restaurants and see who's already planning to dine.")
                    }
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "2.circle.fill").foregroundColor(.orange)
                        Text("Create or join a plan — set the time, size, and goal.")
                    }
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "3.circle.fill").foregroundColor(.orange)
                        Text("Chat in real-time with your group before heading over.")
                    }
                }
                .font(.subheadline)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
            .onAppear {
                Task { await authViewModel.refreshCurrentUser() }
            }
            .sheet(isPresented: $showEditSheet) {
                ProfileEditView(isPresented: $showEditSheet)
                    .environmentObject(authViewModel)
            }
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
            Form {
                Section("Photo") {
                    HStack(spacing: 16) {
                        // Live preview: newly picked > existing remote > initial
                        Group {
                            if let data = pendingAvatarData, let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 64, height: 64)
                                    .clipShape(Circle())
                            } else {
                                AvatarImage(
                                    urlString: authViewModel.avatarURL,
                                    name: displayName.isEmpty ? authViewModel.displayName : displayName,
                                    size: 64,
                                    fontSize: 28
                                )
                            }
                        }

                        PhotosPicker(selection: $pickedItem, matching: .images, photoLibrary: .shared()) {
                            Label("Choose Photo", systemImage: "photo.on.rectangle")
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Display Name") {
                    TextField("Enter your name", text: $displayName)
                }

                Section("Gender") {
                    Picker("Gender", selection: $gender) {
                        Text("Female").tag(Gender.female)
                        Text("Male").tag(Gender.male)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Age (optional)") {
                    TextField("e.g., 27", text: $ageText)
                        .keyboardType(.numberPad)
                }

                Section {
                    TextField("Tell others a bit about yourself", text: $bio, axis: .vertical)
                        .lineLimit(1...4)
                        .onChange(of: bio) { _, newValue in
                            if newValue.count > 150 { bio = String(newValue.prefix(150)) }
                        }
                } header: {
                    Text("Bio")
                } footer: {
                    Text("\(bio.count) / 150")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let error = authViewModel.errorMessage {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                        }
                        .padding(10)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .onAppear {
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

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        var newURL: String? = nil
        if let data = pendingAvatarData {
            newURL = await authViewModel.uploadAvatar(jpegData: data)
            // If upload failed, errorMessage is set — bail without persisting.
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


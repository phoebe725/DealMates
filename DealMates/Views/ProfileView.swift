import SwiftUI
import PhotosUI

// MARK: - ProfileView

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showEditSheet = false

    var body: some View {
        NavigationStack {
            List {
                // Avatar + name
                Section {
                    HStack(spacing: 16) {
                        AvatarImage(
                            urlString: authViewModel.avatarURL,
                            name: authViewModel.displayName,
                            size: 64,
                            fontSize: 28
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(authViewModel.displayName)
                                .font(.title3.bold())
                            Text(authViewModel.isSignedIn ? authViewModel.email : "Anonymous Guest")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if !authViewModel.bio.isEmpty {
                                Text(authViewModel.bio)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                // Account status
                Section("Account Status") {
                    LabeledContent("Mode", value: authViewModel.isSignedIn ? "Registered" : "Guest (Anonymous)")
                    if authViewModel.isSignedIn {
                        LabeledContent("Email", value: authViewModel.email)
                    }
                }

                // Actions
                Section {
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

                        Button(role: .destructive) {
                            Task {
                                await authViewModel.signOut()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.left.circle.fill")
                                Text("Sign Out")
                            }
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

                Section("Bio") {
                    TextEditor(text: $bio)
                        .frame(height: 100)
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
        if authViewModel.errorMessage == nil {
            isPresented = false
        }
    }
}


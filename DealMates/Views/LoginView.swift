import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isSignUpMode = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var gender: Gender = .female
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    Text("DealMates")
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text(isSignUpMode ? "Create your account" : "Welcome back")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.systemGroupedBackground))

                // Form
                ScrollView {
                    VStack(spacing: 16) {
                        // Display name + gender (sign up only)
                        if isSignUpMode {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Display Name", systemImage: "person.fill")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.orange)
                                TextField("e.g., Alex", text: $displayName)
                                    .textFieldStyle(.roundedBorder)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Gender", systemImage: "person.crop.circle")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.orange)
                                Picker("Gender", selection: $gender) {
                                    Text("Female").tag(Gender.female)
                                    Text("Male").tag(Gender.male)
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        // Email
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Email", systemImage: "envelope.fill")
                                .font(.subheadline.bold())
                                .foregroundColor(.orange)
                            TextField("you@example.com", text: $email)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }

                        // Password
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Password", systemImage: "lock.fill")
                                .font(.subheadline.bold())
                                .foregroundColor(.orange)
                            SecureField("At least 8 characters", text: $password)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(isSignUpMode ? .newPassword : .password)
                        }

                        // Error message
                        if let error = authViewModel.errorMessage {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.caption)
                                Spacer()
                            }
                            .padding(10)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                        }

                        // Submit button
                        Button {
                            Task {
                                isLoading = true
                                if isSignUpMode {
                                    await authViewModel.signUp(email: email, password: password, displayName: displayName, gender: gender)
                                } else {
                                    await authViewModel.signIn(email: email, password: password)
                                }
                                isLoading = false
                            }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Text(isSignUpMode ? "Create Account" : "Sign In")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(email.isEmpty || password.isEmpty || (isSignUpMode && displayName.isEmpty) ? Color.gray : Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(email.isEmpty || password.isEmpty || (isSignUpMode && displayName.isEmpty) || isLoading)

                        // Toggle mode
                        Button {
                            isSignUpMode.toggle()
                            authViewModel.errorMessage = nil
                        } label: {
                            HStack(spacing: 4) {
                                Text(isSignUpMode ? "Already have an account?" : "Don't have an account?")
                                    .foregroundColor(.secondary)
                                Text(isSignUpMode ? "Sign In" : "Sign Up")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            }
                            .font(.subheadline)
                        }
                        .padding(.top, 8)

                        Divider()
                            .padding(.vertical, 12)
                    }
                    .padding(20)
                }
            }
            .navigationBarBackButtonHidden()
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}

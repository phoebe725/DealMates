import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    /// Caller chooses which mode the form opens in. Inside the view the user
    /// can still toggle via the link at the bottom.
    var startInSignUp: Bool = false

    @State private var isSignUpMode: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var gender: Gender = .female
    @State private var ageText: String = ""
    @State private var isLoading = false

    init(startInSignUp: Bool = false) {
        self.startInSignUp = startInSignUp
        _isSignUpMode = State(initialValue: startInSignUp)
    }

    var body: some View {
        ZStack {
            Color.pinCream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    form
                    if let error = authViewModel.errorMessage { errorBanner(error) }
                    submitButton
                    toggleModeLink
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 48)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.pinInk)
                }
            }
            ToolbarItem(placement: .principal) {
                PintableWordmark(size: 22)
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(Color.pinCream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarBackButtonHidden()
    }

    // MARK: - Header
    //
    // Paired typography pattern — Inter Regular sets the sentence, Instrument
    // Serif Italic carries the one emotional word. Sentence case everywhere
    // so capitalization never feels accidental.

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Concatenated Text — both halves should LOOK the same size to the
            // eye. Cormorant Garamond Italic has a much smaller x-height than
            // Inter Light, so we compensate with a ~1.4× larger point size on
            // the serif. SwiftUI baseline-aligns the concat, so the line stays
            // flat. If you change one, change the other proportionally.
            if isSignUpMode {
                (
                    Text("Start your ")
                        .font(.pinHero(28, weight: .light))
                        .foregroundStyle(Color.pinInk)
                    +
                    Text("raft.")
                        .font(.pinAccent(40))
                        .foregroundStyle(Color.pinClayDeep)
                )
            } else {
                (
                    Text("Welcome ")
                        .font(.pinHero(28, weight: .light))
                        .foregroundStyle(Color.pinInk)
                    +
                    Text("back.")
                        .font(.pinAccent(40))
                        .foregroundStyle(Color.pinClayDeep)
                )
            }

            Text(isSignUpMode
                 ? "Pin your first plan in a minute."
                 : "Sign in to see what your raft has pinned.")
                .font(.pinSubtitle(15))
                .foregroundStyle(Color.pinInkMuted)
        }
        .padding(.top, 8)
    }

    // MARK: - Form

    private var form: some View {
        VStack(alignment: .leading, spacing: 18) {
            if isSignUpMode {
                field("Your name") {
                    TextField("e.g., Alex", text: $displayName)
                        .pinTextField()
                }

                fieldLabel("Gender")
                Picker("Gender", selection: $gender) {
                    Text("Female").tag(Gender.female)
                    Text("Male").tag(Gender.male)
                }
                .pickerStyle(.segmented)
                .tint(Color.pinClay)

                field("Age (optional)") {
                    TextField("27", text: $ageText)
                        .keyboardType(.numberPad)
                        .pinTextField()
                }
            }

            field("Email") {
                TextField("you@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .pinTextField()
            }

            field("Password") {
                SecureField("At least 8 characters", text: $password)
                    .textContentType(isSignUpMode ? .newPassword : .password)
                    .pinTextField()
            }
        }
    }

    // MARK: - Field builders

    private func field<Content: View>(_ label: LocalizedStringKey, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(label)
            content()
        }
    }

    /// Sentence-case labels in Inter Medium — slightly weightier than body so
    /// the eye lands on them, but never aggressive.
    private func fieldLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.pinBody(14, weight: .medium))
            .foregroundStyle(Color.pinInk)
    }

    // MARK: - Error

    /// `message` is a runtime String (from Supabase Auth errors) so it should
    /// render verbatim — passing it through `Text(_:String)` deliberately
    /// avoids a doomed catalog lookup of error text.
    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Color.pinClayDeep)
            Text(message)
                .font(.pinBody(13))
                .foregroundStyle(Color.pinInk)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.pinClay.opacity(0.12))
        )
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.pinCream)
            } else {
                Text(isSignUpMode ? "Pin me in" : "Sign in")
            }
        }
        .buttonStyle(PinPrimaryButtonStyle())
        .disabled(!canSubmit || isLoading)
        .opacity(canSubmit ? 1 : 0.5)
    }

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && (!isSignUpMode || !displayName.isEmpty)
    }

    private func submit() async {
        isLoading = true
        defer { isLoading = false }
        if isSignUpMode {
            let parsedAge = Int(ageText.trimmingCharacters(in: .whitespaces))
            await authViewModel.signUp(
                email: email, password: password,
                displayName: displayName, gender: gender, age: parsedAge
            )
        } else {
            await authViewModel.signIn(email: email, password: password)
        }
    }

    // MARK: - Toggle mode

    private var toggleModeLink: some View {
        // Both halves are Inter at the same point size — different weights
        // (Regular + SemiBold). Mixing two sans-serif families here made the
        // link visibly taller because Inter has a larger x-height than
        // Nunito Sans. Same family = matched visual size and baseline.
        HStack(spacing: 4) {
            Text(isSignUpMode ? "Already have an account?" : "Don't have an account?")
                .font(.pinBody(14))
                .foregroundStyle(Color.pinInkMuted)
            Button {
                isSignUpMode.toggle()
                authViewModel.errorMessage = nil
            } label: {
                Text(isSignUpMode ? "Sign in" : "Sign up")
            }
            .buttonStyle(PinTextLinkStyle(size: 14))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

// MARK: - Text field styling
//
// Shell background, generous padding, continuous corners, no native border —
// applied to every input so the form reads as one calm surface.

private struct PinTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.pinBody(16))
            .foregroundStyle(Color.pinInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
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

#Preview {
    NavigationStack {
        LoginView(startInSignUp: true)
            .environmentObject(AuthViewModel())
    }
}

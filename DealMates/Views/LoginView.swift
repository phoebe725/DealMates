import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("preferredLanguageCode") private var languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"

    /// Caller chooses which mode the form opens in. Inside the view the user
    /// can still toggle via the link at the bottom.
    var startInSignUp: Bool = false

    @State private var isSignUpMode: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var displayName = ""
    @State private var gender: Gender = .female
    @State private var ageText: String = ""
    @State private var isLoading = false
    @State private var isVerifying = false
    @Environment(\.openURL) private var openURL

    private var isChinese: Bool { languageCode.hasPrefix("zh") }

    init(startInSignUp: Bool = false) {
        self.startInSignUp = startInSignUp
        _isSignUpMode = State(initialValue: startInSignUp)
    }

    var body: some View {
        ZStack {
            Color.pinCream.ignoresSafeArea()

            if let pendingEmail = authViewModel.pendingConfirmationEmail {
                checkInboxView(email: pendingEmail)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header
                        form
                        if let error = authViewModel.errorMessage { errorBanner(error) }
                        if let info = authViewModel.infoMessage { infoBanner(info) }
                        submitButton
                        if !isSignUpMode { forgotPasswordLink }
                        toggleModeLink
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 48)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    // On the inbox screen, "back" returns to the form rather
                    // than abandoning the whole sign-in flow.
                    if authViewModel.pendingConfirmationEmail != nil {
                        authViewModel.cancelPendingConfirmation()
                    } else {
                        dismiss()
                    }
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
        // Wipe any error / "check your email" banner from a previous visit.
        // Without this, the message persists across nav-pops and into the
        // opposite mode (sign-in ↔ sign-up), confusing the user.
        .onAppear  { authViewModel.errorMessage = nil; authViewModel.infoMessage = nil }
        .onDisappear {
            authViewModel.errorMessage = nil
            authViewModel.infoMessage = nil
            authViewModel.cancelPendingConfirmation()
        }
        .onChange(of: isSignUpMode) { _, _ in authViewModel.errorMessage = nil }
        // Presented/pushed (from Profile or the create-plan gate) rather than the
        // root now, so pop back to the app once the account is real & confirmed.
        .onChange(of: authViewModel.isSignedIn) { _, signedIn in
            if signedIn { dismiss() }
        }
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
            //
            // Chinese phrases (`歡迎入座` / `歡迎回來`) don't naturally split
            // into a light + accent pair, so under the Chinese language we
            // collapse to a single accent-weight Text rather than forcing an
            // unnatural break.
            if isSignUpMode {
                (
                    Text("Welcome to the ")
                        .font(.pinHero(28, weight: .light))
                        .foregroundStyle(Color.pinInk)
                    +
                    Text("table.")
                        .font(.pinAccent(40))
                        .foregroundStyle(Color.pinClayDeep)
                )
            } else {
                if isChinese {
                    Text("Welcome back.")
                        .font(.pinAccent(40))
                        .foregroundStyle(Color.pinClayDeep)
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
            }

            Text(isSignUpMode
                 ? "Pin your first plan in a minute."
                 : "Sign in to see your plans and chats.")
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
                // The placeholder is rendered via `prompt: Text(verbatim:)`.
                // Passing "you@example.com" as a LocalizedStringKey would let
                // SwiftUI Markdown auto-link the email pattern and draw it as a
                // blue link — verbatim disables that, so it's plain gray like
                // every other field's placeholder.
                TextField("Email", text: $email, prompt: Text(verbatim: "you@example.com"))
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .pinTextField(tint: Color.pinClay)
            }

            field("Password") {
                HStack(spacing: 8) {
                    Group {
                        if showPassword {
                            TextField("At least 8 characters", text: $password)
                        } else {
                            SecureField("At least 8 characters", text: $password)
                        }
                    }
                    .textContentType(isSignUpMode ? .newPassword : .password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.pinInkMuted)
                    }
                    .buttonStyle(.plain)
                }
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

    // MARK: - Check your inbox
    //
    // Shown after a successful sign-up when the Supabase project requires email
    // confirmation. Mirrors the marketing site: confirm where the link went,
    // a shortcut into Mail, a primary "I've verified" action that retries the
    // sign-in, and a resend fallback.

    private func checkInboxView(email: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.pinClay.opacity(0.12))
                        .frame(width: 64, height: 64)
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(Color.pinClayDeep)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Check your inbox")
                        .font(.pinHero(28, weight: .light))
                        .foregroundStyle(Color.pinInk)
                    // Runtime-interpolated email → render verbatim so it isn't
                    // treated as a catalog key.
                    Text(verbatim: AppLocalization.string("Tap the link we sent to %@ to finish setting up my account.", email))
                        .font(.pinSubtitle(15))
                        .foregroundStyle(Color.pinInkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let info = authViewModel.infoMessage { infoBanner(info) }
                if let error = authViewModel.errorMessage { errorBanner(error) }

                VStack(spacing: 12) {
                    Button {
                        openMailApp()
                    } label: {
                        Label("Open Mail", systemImage: "envelope")
                    }
                    .buttonStyle(PinSecondaryButtonStyle())

                    Button {
                        Task {
                            isVerifying = true
                            defer { isVerifying = false }
                            await authViewModel.signIn(email: email, password: password)
                        }
                    } label: {
                        if isVerifying {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(Color.pinCream)
                        } else {
                            Text("I've verified my email")
                        }
                    }
                    .buttonStyle(PinPrimaryButtonStyle())
                    .disabled(isVerifying)
                }
                .padding(.top, 4)

                HStack(spacing: 4) {
                    Text("Didn't receive an email?")
                        .font(.pinBody(14))
                        .foregroundStyle(Color.pinInkMuted)
                    Button {
                        Task { await authViewModel.resendConfirmation() }
                    } label: {
                        Text("Resend")
                    }
                    .buttonStyle(PinTextLinkStyle(size: 14))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 48)
        }
    }

    /// Opens the system Mail app. We call `openURL` directly (no `canOpenURL`
    /// probe) so we don't need to register query schemes; if no mail client is
    /// installed the open simply no-ops.
    private func openMailApp() {
        if let url = URL(string: "message://") {
            openURL(url)
        }
    }

    private func infoBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.pinSageDeep)
            Text(message)
                .font(.pinBody(13))
                .foregroundStyle(Color.pinInk)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.pinSageDeep.opacity(0.12))
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

    /// Sign-in only — sends a reset email; the link opens the web app to set a
    /// new password. Confirmation/errors surface via info/error banners above.
    private var forgotPasswordLink: some View {
        Button {
            Task { await authViewModel.sendPasswordReset(email: email) }
        } label: {
            Text("Forgot password?")
                .font(.pinBody(14, weight: .medium))
                .foregroundStyle(Color.pinClay)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
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
    /// Cursor / selection / iOS autofill-suggestion color for the field. The
    /// email field overrides this to a muted gray so the autofilled email
    /// suggestion reads as quiet placeholder-style text rather than the default
    /// system blue.
    var tint: Color = .pinClay
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
            .tint(tint)
    }
}

private extension View {
    func pinTextField(tint: Color = .pinClay) -> some View { modifier(PinTextFieldModifier(tint: tint)) }
}

#Preview {
    NavigationStack {
        LoginView(startInSignUp: true)
            .environmentObject(AuthViewModel())
    }
}

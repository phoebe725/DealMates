import SwiftUI

/// Signed-out hero. Stack reads top-to-bottom as:
///   1. Painterly puffin illustration (the brand north star)
///   2. PinTable wordmark
///   3. Tagline — "Plan something *together.*"
///   4. Sub-tagline — "Build your raft."
///   5. Two function CTAs (smaller, since they're functional, not the hero)
struct LaunchView: View {
    var onStart: () -> Void
    var onSignIn: () -> Void

    var body: some View {
        ZStack {
            Color.pinCream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                // 1. Hero illustration + 2. Wordmark.
                // The wordmark always sits below the puffins — the brand-name
                // moment, not a fallback.
                VStack(spacing: 18) {
                    hero
                    // Wordmark is the brand-name moment — sized to read as
                    // clearly bigger than the tagline below. Cormorant SemiBold
                    // Italic has a small x-height, so it needs the higher
                    // point value to feel visually dominant.
                    PintableWordmark(size: 48)
                }

                Spacer(minLength: 28)

                // 3. + 4. Tagline + sub-tagline, vertically grouped.
                VStack(spacing: 10) {
                    tagline
                    Text("Build your raft.")
                        .font(.pinSubtitle(15))
                        .foregroundStyle(Color.pinInkMuted)
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 32)

                // 5. Function CTAs — smaller than the hero so they read as
                // "where to start" rather than the visual focus.
                ctas
                    .padding(.horizontal, 36)
                    .padding(.bottom, 36)
            }
        }
    }

    // MARK: - Hero illustration

    @ViewBuilder
    private var hero: some View {
        if let uiImage = UIImage(named: "launch-hero") {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 280, maxHeight: 280)
        } else {
            // No painterly asset yet — drop a soft peach disc as a placeholder
            // so the composition doesn't collapse. The disc echoes the
            // peach circle behind the puffins in the brand illustration.
            Circle()
                .fill(Color.pinPeach.opacity(0.35))
                .frame(width: 240, height: 240)
        }
    }

    // MARK: - Tagline
    //
    // Same-line concat: Inter Light 26 + Cormorant Italic 36 keeps the visual
    // sizes matched (~1.4× compensates for Cormorant's small x-height) while
    // both fit on a single line on every supported iPhone.

    private var tagline: some View {
        (
            Text("Plan something ")
                .font(.pinHero(26, weight: .light))
                .foregroundStyle(Color.pinInk)
            +
            Text("together.")
                .font(.pinAccent(36))
                .foregroundStyle(Color.pinClayDeep)
        )
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .multilineTextAlignment(.center)
    }

    // MARK: - CTAs

    private var ctas: some View {
        VStack(spacing: 6) {
            Button(action: onStart) {
                Text("Sign up")
            }
            .buttonStyle(PinPrimaryButtonStyle(size: 15))

            Button(action: onSignIn) {
                Text("I already have an account")
            }
            .buttonStyle(PinTextLinkStyle(size: 13))
            .padding(.top, 6)
        }
    }
}

#Preview {
    LaunchView(onStart: {}, onSignIn: {})
}

import SwiftUI

// MARK: - Brand palette
//
// Surfaces, brand, accents, and ink — every visible colour in the app should
// resolve to one of these tokens. Avoid `Color.orange` / `Color.gray` /
// `Color(.systemX)` in new code; reach for the named token instead.

extension Color {
    // Surfaces
    static let pinCream    = Color(hex: "FAF6F0")
    static let pinShell    = Color(hex: "F2EBE0")
    static let pinFog      = Color(hex: "E8DFD1")

    // Brand
    static let pinSage     = Color(hex: "9CAF94")
    static let pinSageDeep = Color(hex: "6B7F62")

    // Accent / CTA
    static let pinClay     = Color(hex: "C97B5C")
    static let pinClayDeep = Color(hex: "A85E42")

    // Secondary accents
    static let pinLavender     = Color(hex: "C5BBD4")
    /// Darker companion for `pinLavender` — use as foreground when the chip
    /// would otherwise read too pale against a tinted shell background.
    static let pinLavenderDeep = Color(hex: "6E5E8E")
    static let pinPeach        = Color(hex: "E8C4A8")
    static let pinSky          = Color(hex: "B8CFD8")
    // Warm sandy yellow — reserved for "raft" / group identification so plan-chats
    // visually distinguish themselves from DMs and individual pin surfaces.
    static let pinSun      = Color(hex: "E0B65A")
    static let pinSunDeep  = Color(hex: "B88E33")

    // Text
    static let pinInk      = Color(hex: "2B2620")
    static let pinInkMuted = Color(hex: "6B6359")

    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        self.init(
            .sRGB,
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8)  & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255,
            opacity: 1
        )
    }
}

// MARK: - Typography
//
// Role-based type system. Pick the role, not the weight — every screen should
// resolve to one of these six.
//
//   • `.pinLogo`     — Cormorant Garamond SemiBold Italic. The PinTable wordmark.
//                      Nothing else.
//   • `.pinHero`     — Inter Light / Regular. The screen's title line.
//   • `.pinAccent`   — Cormorant Garamond Italic. One emotional word per screen.
//   • `.pinBody`     — Inter Regular / Medium. Running text, field values.
//   • `.pinSubtitle` — Nunito Sans Regular. Muted descriptive copy under hero
//                      titles and beneath labels.
//   • `.pinButton`   — Inter SemiBold. Buttons + their inline link siblings.

extension Font {
    static func pinLogo(_ size: CGFloat) -> Font {
        .custom("CormorantGaramond-SemiBoldItalic", size: size)
    }

    static func pinHero(_ size: CGFloat, weight: PinHeroWeight = .light) -> Font {
        switch weight {
        case .light:   return .custom("Inter-Light",   size: size)
        case .regular: return .custom("Inter-Regular", size: size)
        }
    }

    /// Cormorant Garamond Italic has a noticeably smaller x-height than Inter,
    /// so when you concat one of these with `.pinHero(_)` or `.pinBody(_)`
    /// on the same line, give it ~1.4× the point size of the sibling so they
    /// visually match. Same point size on both halves looks like the italic
    /// has been shrunk to half the visual size.
    static func pinAccent(_ size: CGFloat) -> Font {
        .custom("CormorantGaramond-Italic", size: size)
    }

    static func pinBody(_ size: CGFloat, weight: PinBodyWeight = .regular) -> Font {
        switch weight {
        case .regular: return .custom("Inter-Regular", size: size)
        case .medium:  return .custom("Inter-Medium",  size: size)
        }
    }

    static func pinSubtitle(_ size: CGFloat) -> Font {
        .custom("NunitoSans-Regular", size: size)
    }

    static func pinButton(_ size: CGFloat) -> Font {
        .custom("Inter-SemiBold", size: size)
    }
}

/// Explicit weight enums so callers can't accidentally pass `.bold` or `.heavy`
/// — the type system limits the choices to the ones we actually ship.
enum PinHeroWeight { case light, regular }
enum PinBodyWeight { case regular, medium }

// MARK: - Shared style primitives

struct PinCardStyle: ViewModifier {
    var radius: CGFloat = 20
    var fill: Color = .pinShell
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            )
            .shadow(color: Color.pinInk.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}

extension View {
    /// Default container for any "object" surface (a pin row, a poll card, etc.).
    func pinCard(radius: CGFloat = 20, fill: Color = .pinShell) -> some View {
        modifier(PinCardStyle(radius: radius, fill: fill))
    }
}

/// Primary CTA — clay fill, cream text. One per screen.
///
/// `size` controls the type point size; vertical padding scales with it so the
/// button keeps the same proportion at any size. Use the default (17) for the
/// hero submit, a smaller value (14–15) when the CTA is one of several
/// "function" actions and shouldn't dominate the screen.
struct PinPrimaryButtonStyle: ButtonStyle {
    var size: CGFloat = 17
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pinButton(size))
            .foregroundStyle(Color.pinCream)
            .frame(maxWidth: .infinity)
            .padding(.vertical, size * 0.85)
            .background(
                RoundedRectangle(cornerRadius: size * 1.0, style: .continuous)
                    .fill(configuration.isPressed ? Color.pinClayDeep : Color.pinClay)
            )
            .opacity(configuration.isPressed ? 0.95 : 1)
    }
}

/// Secondary CTA — ink text on shell, for low-emphasis actions.
struct PinSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pinButton(17))
            .foregroundStyle(Color.pinInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(configuration.isPressed ? Color.pinFog : Color.pinShell)
            )
    }
}

/// Quiet inline link — text-only, clay color. For toggles between modes etc.
/// `size` is exposed so the link can match the size of the body text it sits
/// next to (same-line concatenations must share a point size, otherwise the
/// baseline visibly steps between the two pieces).
struct PinTextLinkStyle: ButtonStyle {
    var size: CGFloat = 15
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pinButton(size))
            .foregroundStyle(configuration.isPressed ? Color.pinClayDeep : Color.pinClay)
    }
}

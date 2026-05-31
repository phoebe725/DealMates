import Foundation
import CoreText

/// Bundles + registers the brand fonts at app launch. The project uses
/// `GENERATE_INFOPLIST_FILE = YES`, so we register via CTFontManager instead of
/// declaring `UIAppFonts` in a hand-maintained Info.plist. Call once from
/// `DealMatesApp.init()`.
enum FontRegistry {
    /// PostScript names exposed via `Font.custom(...)`. If a font is missing the
    /// system falls back silently — easier to spot during dev when a single name
    /// fails than a whole-app text regression.
    /// Role-based type system. Each file is paired with a single role in
    /// `Font.pin*` so additions here always map to a clear use.
    ///   • Cormorant Garamond Italic        — accent words
    ///   • Cormorant Garamond SemiBold It.  — the PinTable wordmark
    ///   • Inter Light                      — hero titles (light)
    ///   • Inter Regular                    — hero titles (regular) / body
    ///   • Inter Medium                     — body emphasis
    ///   • Inter SemiBold                   — buttons
    ///   • Nunito Sans Regular              — subtitles / muted descriptive
    static let fontFileNames: [String] = [
        "CormorantGaramond-Italic",
        "CormorantGaramond-SemiBoldItalic",
        "Inter-Light",
        "Inter-Regular",
        "Inter-Medium",
        "Inter-SemiBold",
        "NunitoSans-Regular",
    ]

    static func registerAll() {
        for name in fontFileNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                print("[FontRegistry] missing \(name).ttf in bundle")
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                if let err = error?.takeRetainedValue() {
                    let code = CFErrorGetCode(err)
                    // Code 105 = kCTFontManagerErrorAlreadyRegistered — harmless on hot reload.
                    if code != 105 {
                        print("[FontRegistry] register failed for \(name): \(err)")
                    }
                }
            }
        }
    }
}

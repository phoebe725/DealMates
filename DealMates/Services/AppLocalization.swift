import Foundation

/// Bundle-aware replacement for `NSLocalizedString` that ALWAYS resolves the
/// caller's intended language at the moment of the call.
///
/// `NSLocalizedString` is just sugar for `Bundle.main.localizedString(...)`.
/// `Bundle.main` decides which `.lproj` to read from by intersecting
/// `Bundle.main.localizations` with `UserDefaults["AppleLanguages"]` — and
/// caches the result on first access. So when the user switches language
/// in-app, SwiftUI's `Text(LocalizedStringKey)` views re-localize (they read
/// the environment locale), but anything that goes through
/// `NSLocalizedString` keeps using the stale language.
///
/// `AppLocalization.string` re-reads `preferredLanguageCode` on every call and
/// loads the matching `.lproj` directly, sidestepping the cache. Use it
/// anywhere outside SwiftUI text rendering — tab bar items, Plan.timeDisplay,
/// system-message formatting, runtime fallback names.
enum AppLocalization {
    static func string(_ key: String, comment: String = "") -> String {
        let lang = currentLanguageCode()

        // Try the user's chosen language first.
        if let value = lookup(key, in: lang) { return value }

        // Common fallbacks. iOS sometimes ships zh-Hans content under just "zh".
        if lang.hasPrefix("zh-Hans"), let value = lookup(key, in: "zh-Hans") { return value }
        if lang.hasPrefix("zh-Hant"), let value = lookup(key, in: "zh-Hant") { return value }
        if let value = lookup(key, in: "en") { return value }

        return key
    }

    /// Convenience for the common String(format:) pattern.
    static func string(_ key: String, _ args: CVarArg...) -> String {
        let template = string(key)
        return String(format: template, arguments: args)
    }

    // MARK: - Private

    private static func currentLanguageCode() -> String {
        // Match the priority used by `AppLocale.current` in `Restaurant.swift`
        // so model-level translations and UI-level translations agree.
        if let stored = UserDefaults.standard.string(forKey: "preferredLanguageCode"),
           !stored.isEmpty {
            return stored
        }
        return Bundle.main.preferredLocalizations.first
            ?? Locale.current.language.languageCode?.identifier
            ?? "en"
    }

    private static func lookup(_ key: String, in lang: String) -> String? {
        guard let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return nil }
        let value = bundle.localizedString(forKey: key, value: nil, table: nil)
        // Bundle returns the key itself when nothing matched — treat that as a miss.
        return value == key ? nil : value
    }
}

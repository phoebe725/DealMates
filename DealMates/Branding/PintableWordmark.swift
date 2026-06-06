import SwiftUI

/// The PinTable wordmark — **Pin** in clay, **Table** in ink. Two capitalized
/// halves of one camel-case word, both in Instrument Serif Italic. The colour
/// shift pulls out the brand's hidden "Pin" without resorting to weight or
/// typeface changes.
///
/// Under the Chinese in-app language the wordmark switches to **拼桌**
/// (`拼` clay, `桌` ink) — same colour pattern, same intent. The check reads
/// the in-app language picker rather than `Locale.current` so it follows the
/// user's explicit choice even when the system stays on English.
struct PintableWordmark: View {
    var size: CGFloat = 48
    var clayColor: Color = .pinClay
    var inkColor: Color = .pinInk

    @AppStorage("preferredLanguageCode") private var languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"

    var body: some View {
        // `verbatim:` — the wordmark is a brand-name proper noun and must NEVER
        // be looked up in the String Catalog (otherwise the segments themselves
        // would be re-translated unpredictably).
        let (left, right): (String, String) = isChinese
            ? ("拼", "桌")
            : ("Pin", "Table")
        return (
            Text(verbatim: left).foregroundStyle(clayColor)
            +
            Text(verbatim: right).foregroundStyle(inkColor)
        )
        .font(.pinLogo(size))
    }

    private var isChinese: Bool { languageCode.hasPrefix("zh") }
}

#Preview {
    VStack(spacing: 36) {
        PintableWordmark(size: 80)
        PintableWordmark(size: 56)
        PintableWordmark(size: 32)
        PintableWordmark(size: 22)
    }
    .padding(48)
    .background(Color.pinCream)
}

import SwiftUI

/// The PinTable wordmark — **Pin** in clay, **Table** in ink. Two capitalized
/// halves of one camel-case word, both in Instrument Serif Italic. The colour
/// shift pulls out the brand's hidden "Pin" without resorting to weight or
/// typeface changes.
struct PintableWordmark: View {
    var size: CGFloat = 48
    var clayColor: Color = .pinClay
    var inkColor: Color = .pinInk

    var body: some View {
        // `verbatim:` — the wordmark is a brand-name proper noun and must NEVER
        // be localized. Without verbatim, "Pin" gets looked up in the String
        // Catalog and would render as "计划Table" under Chinese.
        (
            Text(verbatim: "Pin").foregroundStyle(clayColor)
            +
            Text(verbatim: "Table").foregroundStyle(inkColor)
        )
        .font(.pinLogo(size))
    }
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

import SwiftUI

// IMPORTANT — about localization:
//
// Each of these components takes `LocalizedStringKey` rather than `String` for
// any user-facing copy. SwiftUI's `Text(someString)` initializer where the
// argument is a `String` value (not a literal) uses the VERBATIM init and does
// NOT look the key up in the String Catalog. Taking `LocalizedStringKey` here
// means literals at the callsite — `PinChip(text: "Organiser")` — get
// localised; the catalog entry's translated value is what renders. For runtime
// strings the caller can construct `LocalizedStringKey(someRuntimeString)`
// explicitly.

// MARK: - Section header

struct PinSectionHeader: View {
    let title: LocalizedStringKey
    init(title: LocalizedStringKey) { self.title = title }

    var body: some View {
        Text(title)
            .font(.pinBody(13, weight: .medium))
            .foregroundStyle(Color.pinInkMuted)
            .padding(.horizontal, 4)
    }
}

// MARK: - Empty state

struct PinEmptyState: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var systemImage: String = "leaf"
    var illustration: String? = nil
    var action: (label: LocalizedStringKey, run: () -> Void)? = nil

    var body: some View {
        VStack(spacing: 18) {
            artwork
                .frame(width: 140, height: 140)

            VStack(spacing: 8) {
                Text(title)
                    .font(.pinHero(22, weight: .regular))
                    .foregroundStyle(Color.pinInk)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.pinSubtitle(14))
                    .foregroundStyle(Color.pinInkMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            if let action {
                Button(action: action.run) {
                    Text(action.label)
                }
                .buttonStyle(PinPrimaryButtonStyle(size: 14))
                .frame(maxWidth: 220)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var artwork: some View {
        if let illustration, let img = UIImage(named: illustration) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            ZStack {
                Circle()
                    .fill(Color.pinPeach.opacity(0.30))
                Image(systemName: systemImage)
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Color.pinClayDeep)
            }
        }
    }
}

// MARK: - Segmented picker

struct PinSegmentedPicker<T: Hashable>: View {
    let options: [(value: T, label: LocalizedStringKey)]
    /// Optional per-option count rendered as a small chip after the label.
    /// Defaults to empty so existing callers keep working unchanged. A value
    /// of 0 is treated as "don't show" so the chip only appears when there's
    /// something for the user to act on.
    var counts: [T: Int] = [:]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                segmentButton(value: option.value, label: option.label)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.pinShell)
        )
    }

    private func segmentButton(value: T, label: LocalizedStringKey) -> some View {
        let isSelected = selection == value
        let count = counts[value] ?? 0
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selection = value
            }
        } label: {
            segmentLabel(label: label, count: count, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func segmentLabel(label: LocalizedStringKey, count: Int, isSelected: Bool) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.pinButton(14))
                .foregroundStyle(isSelected ? Color.pinInk : Color.pinInkMuted)
            if count > 0 {
                Text("\(count)")
                    .font(.pinBody(10, weight: .medium))
                    .foregroundStyle(Color.pinCream)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.pinClay))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.pinCream : Color.clear)
                .shadow(color: Color.pinInk.opacity(isSelected ? 0.06 : 0),
                        radius: 4, x: 0, y: 1)
        )
    }
}

// MARK: - Chip

struct PinChip: View {
    let text: LocalizedStringKey
    var systemImage: String? = nil
    var tint: Color = .pinClay

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2)
            }
            Text(text)
                .font(.pinBody(11, weight: .medium))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.14), in: Capsule(style: .continuous))
    }
}

// MARK: - Search field

struct PinSearchField: View {
    @Binding var text: String
    var placeholder: LocalizedStringKey

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.pinInkMuted)
            TextField(placeholder, text: $text)
                .font(.pinBody(15))
                .foregroundStyle(Color.pinInk)
                .tint(Color.pinClay)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.pinInkMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.pinShell)
        )
    }
}

import SwiftUI

/// Plan / pin card used in `RestaurantBoardView` (and similar places). Header
/// shows the organiser; middle shows notes + preference + status; bottom is
/// the action row.
struct PlanCardView: View {
    let plan: Plan
    let currentUID: String
    let onJoin:    () -> Void
    let onLeave:   () -> Void
    let onOpen:    () -> Void
    let onMessage: () -> Void
    var onOrganiserTap: ((String) -> Void)? = nil

    @ObservedObject private var cache = UserCache.shared

    private var isMember: Bool { plan.isMember(uid: currentUID) }
    private var isOrganiser: Bool { plan.creatorId == currentUID }
    private var liveCreatorName: String {
        cache.name(for: plan.creatorId, fallback: plan.creatorName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            organiserRow
            if !plan.notes.isEmpty { noteBlock }
            statusRow
            Divider().background(Color.pinFog)
            actionRow
        }
        .padding(16)
        .pinCard()
    }

    // MARK: - Organiser row

    private var organiserRow: some View {
        HStack(spacing: 10) {
            Button {
                onOrganiserTap?(plan.creatorId)
            } label: {
                LiveAvatar(
                    userId: plan.creatorId,
                    size: 38,
                    fontSize: 16,
                    fallbackName: plan.creatorName,
                    fallbackAvatarURL: plan.creatorAvatarURL
                )
            }
            .buttonStyle(.plain)
            .disabled(onOrganiserTap == nil)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(liveCreatorName)
                        .font(.pinBody(15, weight: .medium))
                        .foregroundStyle(Color.pinInk)
                        .lineLimit(1)
                    PinChip(text: "Organiser", tint: .pinClay)
                }
                Label(plan.timeDisplay, systemImage: "clock")
                    .font(.pinSubtitle(12))
                    .foregroundStyle(Color.pinInkMuted)
            }

            Spacer()
        }
    }

    // MARK: - Note block

    private var noteBlock: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "quote.opening")
                .font(.caption2)
                .foregroundStyle(Color.pinInkMuted)
            Text(plan.notes)
                .font(.pinBody(13))
                .foregroundStyle(Color.pinInkMuted)
                .lineLimit(3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.pinCream)
        )
    }

    // MARK: - Status row

    private var statusRow: some View {
        HStack(spacing: 8) {
            if plan.genderPreference != .any {
                PinChip(
                    text: LocalizedStringKey(plan.genderPreference.label),
                    systemImage: "person.crop.circle.fill",
                    tint: .pinLavenderDeep
                )
            }
            if plan.needsMorePeople > 0 {
                PinChip(
                    text: "Needs \(plan.needsMorePeople) more",
                    systemImage: "person.3.fill",
                    tint: .pinClay
                )
            } else {
                PinChip(
                    text: "Group is full",
                    systemImage: "checkmark.seal.fill",
                    tint: .pinSageDeep
                )
            }
            Spacer()
            Text("\(plan.currentPeople)/\(plan.neededPeople)")
                .font(.pinBody(12, weight: .medium).monospacedDigit())
                .foregroundStyle(Color.pinInkMuted)
        }
    }

    // MARK: - Action row

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button(action: onOpen) {
                Text("Open")
                    .font(.pinButton(13))
                    .foregroundStyle(Color.pinInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.pinCream)
                    )
            }
            .buttonStyle(.plain)

            if isMember {
                Button(action: onLeave) {
                    Text("Leave")
                        .font(.pinButton(13))
                        .foregroundStyle(Color.pinClayDeep)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.pinClay.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onJoin) {
                    Text("Join")
                        .font(.pinButton(13))
                        .foregroundStyle(Color.pinCream)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(plan.needsMorePeople == 0 ? Color.pinFog : Color.pinClay)
                        )
                }
                .buttonStyle(.plain)
                .disabled(plan.needsMorePeople == 0)
            }

            if !isOrganiser {
                Button(action: onMessage) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.pinSageDeep)
                        .frame(width: 44, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.pinSage.opacity(0.18))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

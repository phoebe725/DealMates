import SwiftUI

struct PlanCardView: View {
    let plan: Plan
    let currentUID: String
    let onJoin:  () -> Void
    let onLeave: () -> Void
    let onOpen:  () -> Void

    private var isMember: Bool { plan.isMember(uid: currentUID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // MARK: Organiser row — avatar + name + time + purpose tag
            HStack(spacing: 10) {
                AvatarImage(
                    urlString: plan.creatorAvatarURL,
                    name: plan.creatorName,
                    size: 36,
                    fontSize: 16
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.creatorName)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Label(plan.timeDisplay, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                PurposeTag(purpose: plan.purpose)
            }

            // MARK: Organiser's comment
            if !plan.notes.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "quote.opening")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(plan.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground))
                )
            }

            // MARK: "Need X more" badge
            HStack(spacing: 6) {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.orange)
                if plan.needsMorePeople > 0 {
                    Text("Need \(plan.needsMorePeople) more")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                } else {
                    Text("Group is full")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }

                Spacer()

                Text("\(plan.currentPeople)/\(plan.neededPeople)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            Divider()

            // MARK: Action buttons
            HStack(spacing: 10) {
                // Open button
                Button(action: onOpen) {
                    Label("Open", systemImage: "arrow.up.right.square")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.blue)

                // Join / Leave button
                if isMember {
                    Button(action: onLeave) {
                        Label("Leave", systemImage: "arrow.uturn.left")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button(action: onJoin) {
                        Label("Join", systemImage: "plus.circle.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(plan.needsMorePeople == 0)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - PurposeTag

struct PurposeTag: View {
    let purpose: PlanPurpose

    private var color: Color {
        switch purpose {
        case .discount: return .green
        case .company:  return .blue
        case .either:   return .orange
        }
    }

    var body: some View {
        Label(purpose.label, systemImage: purpose.icon)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

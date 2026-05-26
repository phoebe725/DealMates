import SwiftUI

struct PlanCardView: View {
    let plan: Plan
    let currentUID: String
    let onJoin:    () -> Void
    let onLeave:   () -> Void
    let onOpen:    () -> Void
    let onMessage: () -> Void

    private var isMember: Bool { plan.isMember(uid: currentUID) }
    private var isOrganiser: Bool { plan.creatorId == currentUID }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // MARK: Organiser row — avatar + name + time
            HStack(spacing: 10) {
                AvatarImage(
                    urlString: plan.creatorAvatarURL,
                    name: plan.creatorName,
                    size: 36,
                    fontSize: 16
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(plan.creatorName)
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text("Organiser")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                    }
                    Label(plan.timeDisplay, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
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
            HStack(spacing: 6) {
                Button(action: onOpen) {
                    Text("Open")
                        .font(.caption.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.blue)

                if isMember {
                    Button(action: onLeave) {
                        Text("Leave")
                            .font(.caption.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button(action: onJoin) {
                        Text("Join")
                            .font(.caption.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(plan.needsMorePeople == 0)
                }

                if !isOrganiser {
                    Button(action: onMessage) {
                        Text("Message Organiser")
                            .font(.caption.bold())
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple)
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

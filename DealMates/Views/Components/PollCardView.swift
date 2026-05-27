import SwiftUI

struct PollCardView: View {
    let poll: Poll
    let votes: [PollVote]
    let currentUid: String
    let onVote: (Int) -> Void

    private var totalVotes: Int { votes.count }
    private var myVoteIndex: Int? { votes.first(where: { $0.userId == currentUid })?.optionIndex }

    private func count(for index: Int) -> Int {
        votes.filter { $0.optionIndex == index }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.orange)
                Text(poll.question)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(totalVotes) votes")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            ForEach(Array(poll.options.enumerated()), id: \.offset) { index, option in
                optionRow(index: index, option: option)
            }

            Text("by \(poll.creatorName)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }

    private func optionRow(index: Int, option: String) -> some View {
        let n = count(for: index)
        let isMine = myVoteIndex == index
        let pct: Double = totalVotes > 0 ? Double(n) / Double(totalVotes) : 0

        return Button {
            onVote(index)
        } label: {
            ZStack(alignment: .leading) {
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isMine ? Color.orange.opacity(0.25) : Color(.systemGray5))
                        .frame(width: max(28, geo.size.width * pct), height: 32)
                }
                .frame(height: 32)

                HStack {
                    if isMine {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.orange)
                    }
                    Text(option)
                        .font(.caption)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(n)")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 32)
        }
        .buttonStyle(.plain)
    }
}

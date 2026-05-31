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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.pinClay)
                Text(poll.question)
                    .font(.pinBody(14, weight: .medium))
                    .foregroundStyle(Color.pinInk)
                Spacer()
                Text("\(totalVotes) votes")
                    .font(.pinSubtitle(11).monospacedDigit())
                    .foregroundStyle(Color.pinInkMuted)
            }

            VStack(spacing: 6) {
                ForEach(Array(poll.options.enumerated()), id: \.offset) { index, option in
                    optionRow(index: index, option: option)
                }
            }

            Text("by \(poll.creatorName)")
                .font(.pinSubtitle(11))
                .foregroundStyle(Color.pinInkMuted)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.pinShell)
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
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isMine ? Color.pinClay.opacity(0.22) : Color.pinCream)
                        .frame(width: max(32, geo.size.width * pct), height: 34)
                }
                .frame(height: 34)

                HStack(spacing: 6) {
                    if isMine {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.pinClay)
                    }
                    Text(option)
                        .font(.pinBody(13))
                        .foregroundStyle(Color.pinInk)
                    Spacer()
                    Text("\(n)")
                        .font(.pinSubtitle(12).monospacedDigit())
                        .foregroundStyle(Color.pinInkMuted)
                }
                .padding(.horizontal, 10)
            }
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isMine ? Color.pinClay.opacity(0.30) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

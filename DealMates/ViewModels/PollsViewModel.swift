import SwiftUI
import Combine

@MainActor
final class PollsViewModel: ObservableObject {
    @Published var polls: [Poll] = []
    @Published var votesByPoll: [String: [PollVote]] = [:]
    @Published var errorMessage: String?

    let planId: String
    private var listenerTask: Task<Void, Never>?
    private let service = DatabaseService.shared

    init(planId: String) {
        self.planId = planId
    }

    deinit { listenerTask?.cancel() }

    func startListening() {
        Task { await load() }
        listenerTask = service.listenToPolls(planId: planId) { [weak self] in
            await self?.load()
        }
    }

    func stopListening() {
        listenerTask?.cancel()
        listenerTask = nil
    }

    func load() async {
        async let pollsTask = service.fetchPolls(planId: planId)
        async let votesTask = service.fetchVotes(planId: planId)
        // Only overwrite local state on successful fetch so a transient network blip
        // doesn't wipe existing polls/votes from the UI.
        if let fetchedPolls = try? await pollsTask {
            polls = fetchedPolls
        }
        if let fetchedVotes = try? await votesTask {
            votesByPoll = Dictionary(grouping: fetchedVotes, by: \.pollId)
        }
    }

    func createPoll(question: String, options: [String], userId: String, userName: String) async {
        let poll = Poll(planId: planId, creatorId: userId, creatorName: userName, question: question, options: options)
        do {
            try await service.createPoll(poll)
            await load()
        } catch {
            print("[DEBUG] createPoll failed: \(error)")
        }
    }

    func vote(pollId: String, optionIndex: Int, userId: String) async {
        guard !userId.isEmpty else {
            errorMessage = "You need to be signed in to vote."
            return
        }
        let vote = PollVote(pollId: pollId, userId: userId, optionIndex: optionIndex)

        // Optimistic local update so the user gets immediate feedback.
        var existing = votesByPoll[pollId] ?? []
        existing.removeAll { $0.userId == userId }
        existing.append(vote)
        votesByPoll[pollId] = existing

        do {
            try await service.castVote(vote)
            await load()
        } catch {
            print("[DEBUG] vote failed: \(error)")
            errorMessage = error.localizedDescription
            await load() // revert optimistic update by reloading authoritative state
        }
    }
}

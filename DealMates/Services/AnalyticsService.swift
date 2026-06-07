import Foundation

/// Minimal first-party analytics — mirrors web/src/lib/analytics.ts. Events are
/// inserted into the shared `analytics_events` table; `user_id` ties each event
/// to the (guest or registered) user so activity is attributable, and screen
/// time is logged via session_start / session_heartbeat / session_end.
/// Fire-and-forget — never blocks the UI.
@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    private let client = SupabaseManager.shared.client
    private let guestKey = "pintable_guest_id"
    private let sessionId = UUID().uuidString.lowercased() // per app launch
    private var userId: String?
    private var sessionStart = Date()
    private var sessionStarted = false
    private var heartbeat: Task<Void, Never>?

    /// Stable per-install anonymous id (UserDefaults), mirroring the web localStorage id.
    private var guestId: String {
        if let g = UserDefaults.standard.string(forKey: guestKey) { return g }
        let g = UUID().uuidString.lowercased()
        UserDefaults.standard.set(g, forKey: guestKey)
        return g
    }

    private struct Event: Encodable {
        let event_name: String
        let user_id: String?
        let guest_id: String
        let session_id: String
        let restaurant_id: String?
        let offer_id: String?
        let plan_id: String?
        let metadata: [String: Int]?
    }

    /// The current auth uid (guest or registered), set from the app on launch /
    /// when the user changes.
    func setUser(_ uid: String?) {
        userId = (uid?.isEmpty ?? true) ? nil : uid
    }

    func track(_ event: String,
               restaurantId: String? = nil,
               offerId: String? = nil,
               planId: String? = nil,
               metadata: [String: Int]? = nil) {
        let row = Event(event_name: event, user_id: userId, guest_id: guestId, session_id: sessionId,
                        restaurant_id: restaurantId, offer_id: offerId, plan_id: planId, metadata: metadata)
        Task { try? await client.from("analytics_events").insert(row).execute() }
    }

    // MARK: - Screen time

    private var elapsedMs: Int { Int(Date().timeIntervalSince(sessionStart) * 1000) }

    /// Begin (or resume after backgrounding) a foreground timing segment.
    func startSession() {
        guard !sessionStarted else { return }
        sessionStarted = true
        sessionStart = Date()
        track("session_start")
        heartbeat?.cancel()
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s
                guard let self, !Task.isCancelled else { break }
                self.track("session_heartbeat", metadata: ["elapsed_ms": self.elapsedMs])
            }
        }
    }

    /// End the current foreground segment, logging its duration.
    func endSession() {
        guard sessionStarted else { return }
        heartbeat?.cancel()
        heartbeat = nil
        track("session_end", metadata: ["duration_ms": elapsedMs])
        sessionStarted = false
    }
}

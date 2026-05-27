import Foundation
import EventKit

enum CalendarServiceError: LocalizedError {
    case accessDenied
    case eventCreationFailed
    var errorDescription: String? {
        switch self {
        case .accessDenied:        return NSLocalizedString("Calendar access was denied. Enable it in Settings.", comment: "")
        case .eventCreationFailed: return NSLocalizedString("Could not create the calendar event.", comment: "")
        }
    }
}

/// Adds a confirmed plan to the user's default iOS calendar.
final class CalendarService {
    static let shared = CalendarService()
    private let store = EKEventStore()

    func addPlanToCalendar(plan: Plan) async throws {
        try await ensureAccess()
        guard let cal = store.defaultCalendarForNewEvents else {
            throw CalendarServiceError.eventCreationFailed
        }
        let event = EKEvent(eventStore: store)
        event.calendar = cal
        event.title = "DealMates: \(plan.restaurantName)"
        let start: Date
        switch plan.timeType {
        case .asap, .scheduled: start = plan.scheduledAt
        case .flexible:         start = plan.scheduledAt // best guess; flexible plans should be locked first
        }
        event.startDate = start
        event.endDate   = start.addingTimeInterval(2 * 3600)
        event.notes     = plan.notes.isEmpty ? "Group dining plan" : plan.notes
        event.location  = plan.restaurantName
        do {
            try store.save(event, span: .thisEvent)
        } catch {
            throw CalendarServiceError.eventCreationFailed
        }
    }

    private func ensureAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .denied, .restricted:
            throw CalendarServiceError.accessDenied
        case .notDetermined:
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = (try? await store.requestFullAccessToEvents()) ?? false
            } else {
                granted = await withCheckedContinuation { cont in
                    store.requestAccess(to: .event) { ok, _ in cont.resume(returning: ok) }
                }
            }
            if !granted { throw CalendarServiceError.accessDenied }
        default:
            return // .authorized, .fullAccess, .writeOnly — all allow writing
        }
    }
}

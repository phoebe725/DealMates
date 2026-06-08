import SwiftUI
import Combine

/// Routes incoming `pintable://` deep links. Currently handles shared plan
/// links of the form `pintable://plan/<id>`: it loads the plan and publishes it
/// so the app can present it from the root (see DealMatesApp).
///
/// The matching public web page lives at docs/plan.html and is what actually
/// gets shared (so recipients without the app see an invite + download path);
/// that page's "Open in PinTable" button is what fires the custom scheme below.
@MainActor
final class DeepLinkRouter: ObservableObject {
    /// When set, the app presents PlanDetailView for this plan.
    @Published var plan: Plan?

    /// Deployed web app base for shareable links.
    private static let webBase = "https://pintable-london.web.app"

    /// The https invite link to share for a plan — opens the plan directly in
    /// the web app (which falls back to Discover if the plan can't load).
    static func shareURL(for plan: Plan) -> URL {
        URL(string: "\(webBase)/plan/\(plan.id)")!
    }

    func handle(_ url: URL) {
        guard url.scheme?.lowercased() == "pintable" else { return }
        // pintable://plan/<id>
        guard url.host == "plan" else { return }
        let id = url.pathComponents.first { $0 != "/" }
        guard let id, !id.isEmpty else { return }
        Task {
            if let loaded = try? await DatabaseService.shared.fetchPlan(id: id) {
                plan = loaded
            }
        }
    }
}

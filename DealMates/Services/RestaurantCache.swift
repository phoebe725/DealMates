import SwiftUI
import Combine

/// In-memory cache of every restaurant we've seen, keyed by id. The restaurant list is small
/// and changes rarely, so we load it once at launch and refetch on demand. Views that show
/// `plan.restaurantName` (which is an English snapshot) should resolve through
/// `displayName(for:)` here so the in-app language picker actually swaps the name.
@MainActor
final class RestaurantCache: ObservableObject {
    static let shared = RestaurantCache()

    @Published var restaurants: [String: Restaurant] = [:]

    private var loadTask: Task<Void, Never>?
    private let service = DatabaseService.shared

    // MARK: - Read

    func restaurant(for id: String) -> Restaurant? { restaurants[id] }

    /// Locale-aware restaurant name. Falls back to the snapshot string when the cache hasn't
    /// loaded yet (e.g., cold launch into a deep link).
    func displayName(for restaurantId: String, fallback: String) -> String {
        restaurants[restaurantId]?.displayName ?? fallback
    }

    // MARK: - Load

    /// Fetch every restaurant once. Subsequent calls reuse the in-flight task or return
    /// immediately if the cache is already populated.
    func loadAll() async {
        if !restaurants.isEmpty { return }
        if let existing = loadTask { await existing.value; return }
        let task = Task {
            do {
                let all = try await service.fetchRestaurants()
                self.restaurants = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
            } catch {
                print("[DEBUG] RestaurantCache.loadAll failed: \(error)")
            }
        }
        loadTask = task
        await task.value
        loadTask = nil
    }

    /// Force a refresh from the server — useful after a language change so the cache picks up
    /// any newly-arrived translations.
    func reload() async {
        loadTask?.cancel()
        loadTask = nil
        restaurants.removeAll()
        await loadAll()
    }
}

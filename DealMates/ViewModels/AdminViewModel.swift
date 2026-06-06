import SwiftUI
import Combine
import MapKit

/// Backs the founder-only admin view. Owns the full restaurant list (for the
/// featured toggles) and a MapKit search for adding new venues. Founder-gated
/// at the call site.
@MainActor
final class AdminViewModel: ObservableObject {
    @Published var restaurants: [Restaurant] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Add-place search
    @Published var addQuery = ""
    @Published var mapResults: [Restaurant] = []

    private let service = DatabaseService.shared
    private let region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5114, longitude: -0.1281),
        latitudinalMeters: 12_000, longitudinalMeters: 12_000)

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            restaurants = (try await service.fetchRestaurants()).sorted { $0.name < $1.name }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Featured

    func setFeatured(_ restaurant: Restaurant, _ isFeatured: Bool) async {
        do {
            try await service.setRestaurantFeatured(id: restaurant.id, isFeatured: isFeatured)
            if let idx = restaurants.firstIndex(where: { $0.id == restaurant.id }) {
                restaurants[idx].isFeatured = isFeatured
            }
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: Add place (MapKit)

    func searchMap() async {
        let found = await MapKitSearchService.search(addQuery, near: region)
        let existing = Set(restaurants.map(\.id))
        mapResults = found.filter { !existing.contains($0.id) }
    }

    func addRestaurant(_ base: Restaurant, cuisine: String, isFeatured: Bool) async {
        var r = base
        r.cuisine = cuisine.trimmingCharacters(in: .whitespaces).isEmpty ? base.cuisine : cuisine
        r.isFeatured = isFeatured
        do {
            let saved = try await service.upsertRestaurant(r)
            if let idx = restaurants.firstIndex(where: { $0.id == saved.id }) { restaurants[idx] = saved }
            else { restaurants.append(saved); restaurants.sort { $0.name < $1.name } }
            mapResults.removeAll { $0.id == saved.id }
        } catch { errorMessage = error.localizedDescription }
    }
}

import SwiftUI
import Combine

@MainActor
final class RestaurantViewModel: ObservableObject {
    @Published var restaurants: [Restaurant] = []
    @Published var filteredRestaurants: [Restaurant] = []
    @Published var searchText = "" {
        didSet { applyFilter() }
    }
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = DatabaseService.shared

    // MARK: - Actions

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            restaurants = try await service.fetchRestaurants()
            print("[DEBUG] Loaded \(restaurants.count) restaurants")
            applyFilter()
        } catch {
            print("[DEBUG] Failed to load restaurants: \(error)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refreshActivePlanCount(for restaurantId: String) async {
        if let updated = try? await service.fetchRestaurant(id: restaurantId),
           let idx = restaurants.firstIndex(where: { $0.id == restaurantId }) {
            restaurants[idx] = updated
            applyFilter()
        }
    }

    // MARK: - Private

    private func applyFilter() {
        guard !searchText.isEmpty else {
            filteredRestaurants = restaurants
            return
        }
        let q = searchText.lowercased()
        filteredRestaurants = restaurants.filter {
            $0.name.lowercased().contains(q) ||
            $0.cuisine.lowercased().contains(q)
        }
    }
}

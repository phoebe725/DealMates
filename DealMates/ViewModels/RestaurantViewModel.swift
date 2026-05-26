import SwiftUI
import Combine

@MainActor
final class RestaurantViewModel: ObservableObject {
    @Published var restaurants: [Restaurant] = []
    @Published var filteredRestaurants: [Restaurant] = []
    @Published var searchText = "" {
        didSet { applyFilter() }
    }
    @Published var cuisineFilter: String? = nil {
        didSet { applyFilter() }
    }
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Sorted, unique cuisine list from loaded restaurants.
    var availableCuisines: [String] {
        Array(Set(restaurants.map(\.cuisine))).sorted()
    }

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
        var result = restaurants
        if let cuisine = cuisineFilter, !cuisine.isEmpty {
            result = result.filter { $0.cuisine == cuisine }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(q) ||
                $0.cuisine.lowercased().contains(q)
            }
        }
        filteredRestaurants = result
    }
}

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

    /// Synthetic cross-cuisine filter chips. "AYCE / Buffet" is driven by the
    /// restaurant's `is_buffet` column (source of truth); "🔥 Deals" by whether
    /// the restaurant has any deals.
    static let dealsCategory  = "🔥 Deals"
    static let buffetCategory = "AYCE / Buffet"

    /// Sorted, unique cuisine list from loaded restaurants — reflects the actual
    /// `cuisine` values in the table (no client-side hiding). The "AYCE / Buffet"
    /// category is prepended when any loaded venue qualifies.
    var availableCuisines: [String] {
        var cuisines = Array(Set(restaurants.map(\.cuisine))).filter { $0 != Self.buffetCategory }.sorted()
        if restaurants.contains(where: { $0.isBuffet }) {
            cuisines.insert(Self.buffetCategory, at: 0)
        }
        if restaurants.contains(where: { !$0.displayDeals.isEmpty }) {
            cuisines.insert(Self.dealsCategory, at: 0)
        }
        return cuisines
    }

    private let service = DatabaseService.shared

    // MARK: - Actions

    func load() async {
        // Only show the full-screen loading state on the first load. Auto-
        // refresh-on-appear / pull-to-refresh keeps the existing list visible
        // and just swaps content in when the fetch returns.
        let isFirstLoad = restaurants.isEmpty
        if isFirstLoad { isLoading = true }
        errorMessage = nil
        do {
            restaurants = try await service.fetchRestaurants()
            applyFilter()
        } catch {
            print("[DEBUG] Failed to load restaurants: \(error)")
            errorMessage = error.localizedDescription
        }
        if isFirstLoad { isLoading = false }
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
            if cuisine == Self.dealsCategory {
                result = result.filter { !$0.displayDeals.isEmpty }
            } else if cuisine == Self.buffetCategory {
                result = result.filter { $0.isBuffet }
            } else {
                result = result.filter { $0.cuisine == cuisine }
            }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(q) ||
                $0.cuisine.lowercased().contains(q) ||
                ($0.nameZhHans ?? "").contains(q) ||
                ($0.nameZhHant ?? "").contains(q)
            }
        }
        filteredRestaurants = result
    }
}

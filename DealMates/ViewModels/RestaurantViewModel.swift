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

    /// Synthetic cross-cuisine category for venues with a real all-you-can-eat
    /// / buffet menu (researched, curated by id — not a stored field). Shown as
    /// its own filter chip.
    static let buffetCategory = "AYCE / Buffet"
    static let buffetRestaurantIDs: Set<String> = [
        // Existing restaurants whose primary cuisine is not "AYCE / Buffet"
        // but which offer a buffet/AYCE menu.
        "e6f9a2b3-3a4d-4e7f-6c8b-9e1d3e5a8c1e", // Yauatcha — Soho
        "a2b56d7e-8c9f-4a3b-2e4d-5a6f8a1c4e6a", // Happy Lamb Hot Pot — Bayswater
        "a2b5c7d8-8c9f-4a3b-2e4d-5a6f8a1c4e6a", // Eat Tokyo — Soho
        "fe3c6f9d-2a3b-4c5d-6e7f-8a9b0c1d2e3f", // Haidilao — O2
        "7ffaadc0-1b2c-3d4e-5f6a-7b8c9d0e1f2a", // Haidilao — Piccadilly
        "52a665e1-3c4d-5e6f-7a8b-9c0d1e2f3a4b", // Da Long Yi — Fitzrovia
        "8833e03a-2c3e-4d5f-9a8b-1c2e3d4f5a6b", // Ning's — Chinatown
        "105b7fbd-8a9b-4c5d-2e3f-6a7b8c9d0e1f", // Ning's — Tottenham Street
        "fa0e7619-1234-5678-abcd-ef0123456789", // Ai Sushi — North Finchley
        "098dcf82-4e5f-6a7b-8c9d-0e1f2a3b4c5d", // Mu Yang Ren — Shepherd's Bush
        "75ce5b67-5f6a-7b8c-9d0e-1f2a3b4c5d6e", // Sumiya — Shoreditch
        "7540f6f8-6a7b-8c9d-0e1f-2a3b4c5d6e7f", // Er Mei — Chinatown
    ]

    /// Sorted, unique cuisine list from loaded restaurants — reflects the actual
    /// `cuisine` values in the table (no client-side hiding). The "AYCE / Buffet"
    /// category is prepended when any loaded venue qualifies.
    var availableCuisines: [String] {
        var cuisines = Array(Set(restaurants.map(\.cuisine))).filter { $0 != Self.buffetCategory }.sorted()
        if restaurants.contains(where: { Self.buffetRestaurantIDs.contains($0.id) || $0.cuisine == Self.buffetCategory }) {
            cuisines.insert(Self.buffetCategory, at: 0)
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
            if cuisine == Self.buffetCategory {
                result = result.filter { Self.buffetRestaurantIDs.contains($0.id) || $0.cuisine == Self.buffetCategory }
            } else {
                result = result.filter { $0.cuisine == cuisine }
            }
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

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
    /// Deal filter — one of all/group/ayce/discount/student/member, separate
    /// from cuisine. AYCE/Buffet is a deal filter here, not a cuisine.
    @Published var dealFilter: String? = nil {
        didSet { applyFilter() }
    }
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// Active offers grouped by restaurant id (restaurant_offers table).
    @Published var offersByRestaurant: [String: [RestaurantOffer]] = [:]

    /// Deal-filter chips (value, emoji, label key) — separate from cuisine.
    static let dealFilterChips: [(value: String, emoji: String, key: String)] = [
        ("all", "🔥", "All Deals"), ("group", "👥", "Group Deals"), ("ayce", "🍽", "AYCE / Buffet"),
        ("discount", "💸", "Discounts"), ("student", "🎓", "Student"), ("member", "💳", "Member"),
    ]

    /// Offers-first, with legacy displayDeals as fallback when a restaurant has
    /// no rows in restaurant_offers (or the table isn't there yet).
    func offers(for r: Restaurant) -> [RestaurantOffer] {
        if let o = offersByRestaurant[r.id], !o.isEmpty { return o }
        return r.displayDeals.enumerated().map { RestaurantOffer.fromDeal($1, restaurantId: r.id, index: $0) }
    }

    /// Deal filters that at least one loaded restaurant qualifies for.
    var availableDealFilters: [(value: String, emoji: String, key: String)] {
        Self.dealFilterChips.filter { chip in
            restaurants.contains { RestaurantOffer.matchesFilter(offers(for: $0), chip.value) }
        }
    }

    /// Pure cuisine list — AYCE/Buffet is a deal filter now, not a cuisine.
    var availableCuisines: [String] {
        Array(Set(restaurants.map(\.cuisine))).filter { $0 != "AYCE / Buffet" }.sorted()
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
            offersByRestaurant = await service.fetchOffersMap()
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
        if let f = dealFilter, !f.isEmpty {
            result = result.filter { RestaurantOffer.matchesFilter(offers(for: $0), f) }
        }
        if let cuisine = cuisineFilter, !cuisine.isEmpty {
            result = result.filter { $0.cuisine == cuisine }
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

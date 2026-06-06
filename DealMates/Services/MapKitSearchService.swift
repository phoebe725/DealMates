import Foundation
import MapKit
import CryptoKit

/// Thin wrapper over `MKLocalSearch` used as a fallback when a user searches for
/// a venue that isn't in the curated `restaurants` set. Results are mapped into
/// `Restaurant` values (with `isFeatured = false`) so the rest of the app — the
/// board, plan-pinning, the cards — can treat them uniformly. They only become
/// real rows once `DatabaseService.upsertRestaurant` is called (on pin).
enum MapKitSearchService {

    /// Searches Apple Maps for `query`, optionally biased to `region`.
    /// Returns up to a handful of restaurant-like results.
    static func search(_ query: String, near region: MKCoordinateRegion? = nil) async -> [Restaurant] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = [.pointOfInterest]
        if let region { request.region = region }

        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.prefix(12).compactMap(restaurant(from:))
        } catch {
            print("[DEBUG] MapKit search failed: \(error)")
            return []
        }
    }

    /// Builds a `Restaurant` from an Apple Maps result. The id is derived
    /// deterministically from name + coordinates so the same place always maps
    /// to the same row (upserts dedupe instead of piling up duplicates).
    private static func restaurant(from item: MKMapItem) -> Restaurant? {
        let placemark = item.placemark
        guard let name = item.name, !name.isEmpty else { return nil }
        let coord = placemark.coordinate

        return Restaurant(
            id: deterministicID(name: name, lat: coord.latitude, lon: coord.longitude),
            name: name,
            cuisine: cuisine(for: item.pointOfInterestCategory),
            address: shortAddress(from: placemark),
            imageUrl: nil,
            latitude: coord.latitude,
            longitude: coord.longitude,
            isFeatured: false
        )
    }

    /// A stable lowercased-UUID string from the venue's identity. Takes the
    /// first 16 bytes of SHA-256(name|lat|lon) and formats them as a UUID — same
    /// inputs → same id, matching the app's lowercased-uuid convention.
    private static func deterministicID(name: String, lat: Double, lon: Double) -> String {
        let key = "\(name.lowercased())|\(String(format: "%.5f", lat))|\(String(format: "%.5f", lon))"
        let digest = SHA256.hash(data: Data(key.utf8))
        let chars = Array(digest.prefix(16).map { String(format: "%02x", $0) }.joined())
        func slice(_ a: Int, _ b: Int) -> String { String(chars[a..<b]) }
        return "\(slice(0,8))-\(slice(8,12))-\(slice(12,16))-\(slice(16,20))-\(slice(20,32))"
    }

    private static func shortAddress(from p: MKPlacemark) -> String {
        [p.thoroughfare, p.locality, p.postalCode]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    /// Loose label from the Apple Maps POI category. The user can refine the
    /// cuisine later in the admin view; here we just avoid an empty string.
    private static func cuisine(for category: MKPointOfInterestCategory?) -> String {
        switch category {
        case .some(.cafe):     return "Cafe"
        case .some(.bakery):   return "Bakery"
        default:               return "Restaurant"
        }
    }
}

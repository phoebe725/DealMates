import Foundation
import Supabase

// MARK: - SupabaseManager

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    /// JSONDecoder pre-configured for Supabase responses (snake_case → camelCase, ISO-8601 dates).
    let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // Use explicit CodingKeys in models instead of automatic snake_case conversion
        d.keyDecodingStrategy = .useDefaultKeys
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            // Supabase can return timestamps with or without fractional seconds
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = f.date(from: raw) { return date }
            f.formatOptions = [.withInternetDateTime]
            if let date = f.date(from: raw) { return date }
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Cannot parse date: \(raw)"))
        }
        return d
    }()

    /// JSONEncoder pre-configured for Supabase inserts/updates (camelCase → snake_case, ISO-8601 dates).
    var encoder: JSONEncoder = {
        let e = JSONEncoder()
        // Use explicit CodingKeys in models instead of automatic snake_case conversion
        e.keyEncodingStrategy = .useDefaultKeys
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private init() {
        let options = SupabaseClientOptions()
        
        client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey,
            options: options
        )
    }
}

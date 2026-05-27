import SwiftUI

/// Avatar that resolves its name + image URL from `UserCache` for the given user id, falling
/// back to the snapshot values (e.g. `message.senderName`) until the cache is populated.
/// Updates automatically whenever the underlying user row changes.
struct LiveAvatar: View {
    let userId: String
    let size: CGFloat
    let fontSize: CGFloat
    var fallbackName: String = ""
    var fallbackAvatarURL: String? = nil

    @ObservedObject private var cache = UserCache.shared

    var body: some View {
        AvatarImage(
            urlString: cache.avatarURL(for: userId, fallback: fallbackAvatarURL),
            name: cache.name(for: userId, fallback: fallbackName),
            size: size,
            fontSize: fontSize
        )
        .task(id: userId) {
            await cache.ensure(id: userId)
        }
    }
}

/// Companion helper that exposes the live display name as a String — handy when the caller
/// needs to interpolate the name into other text (e.g. "Alice: hello").
struct LiveUserName {
    let userId: String
    var fallback: String = ""

    @MainActor
    func resolve(_ cache: UserCache = .shared) -> String {
        cache.name(for: userId, fallback: fallback)
    }
}

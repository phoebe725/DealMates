import SwiftUI
import UIKit

/// In-memory image cache keyed by URL. Synchronous reads so views can show the image on first frame
/// without flashing a placeholder if it's already been fetched once during this app session.
final class ImageCache {
    static let shared = ImageCache()
    private let lock = NSLock()
    private var store: [URL: UIImage] = [:]

    func image(for url: URL) -> UIImage? {
        lock.lock(); defer { lock.unlock() }
        return store[url]
    }

    func set(_ image: UIImage, for url: URL) {
        lock.lock(); defer { lock.unlock() }
        store[url] = image
    }
}

/// AsyncImage replacement that caches UIImage in memory so once a URL has loaded,
/// it never flashes a placeholder again on subsequent appearances.
struct CachedAsyncImage<Placeholder: View, Failure: View>: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    @ViewBuilder let placeholder: () -> Placeholder
    @ViewBuilder let failure: () -> Failure
    @State private var uiImage: UIImage?
    @State private var didFail: Bool = false

    init(
        url: URL?,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = placeholder
        self.failure = failure
        if let url, let cached = ImageCache.shared.image(for: url) {
            _uiImage = State(initialValue: cached)
        }
    }

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if didFail {
                failure()
            } else {
                placeholder()
                    .task(id: url) { await load() }
            }
        }
    }

    private func load() async {
        guard let url else { return }
        if let cached = ImageCache.shared.image(for: url) {
            uiImage = cached
            return
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let img = UIImage(data: data) else {
                didFail = true
                return
            }
            ImageCache.shared.set(img, for: url)
            uiImage = img
        } catch {
            didFail = true
        }
    }
}

import SwiftUI
import UIKit

/// Circular avatar that renders the remote image when `urlString` is set,
/// otherwise falls back to the app's puffin mark (the default for guests and
/// anyone without a photo). `name`/`fontSize` are kept for call-site API
/// compatibility but no longer drive a letter avatar.
struct AvatarImage: View {
    let urlString: String?
    let name: String
    let size: CGFloat
    let fontSize: CGFloat

    var body: some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                case .failure:
                    initialBubble
                case .empty:
                    initialBubble
                        .overlay(ProgressView())
                @unknown default:
                    initialBubble
                }
            }
        } else {
            initialBubble
        }
    }

    private var initialBubble: some View {
        ZStack {
            Circle()
                .fill(Color.pinSage.opacity(0.25))
                .frame(width: size, height: size)
            PuffinMark(size: size * 0.72)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    /// Downscale (longest side ≤ 512px) and JPEG-compress at 0.8 for upload.
    static func compressedJPEG(from data: Data, maxDimension: CGFloat = 512) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}

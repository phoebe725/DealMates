import SwiftUI

/// Side-profile geometric puffin. Doubles as a map-pin silhouette — the body
/// reads as the pin teardrop, the beak as the marker tip. Use as the primary
/// brand mark beside the wordmark or as a small navigation accent.
struct PuffinMark: View {
    var size: CGFloat = 120
    var bodyColor: Color = .pinInk
    var bellyColor: Color = .pinCream
    var beakColor: Color = .pinClay
    var beakHighlight: Color = .pinPeach

    var body: some View {
        ZStack {
            Ellipse()
                .fill(bodyColor)
                .frame(width: size * 0.78, height: size * 0.92)
                .offset(x: size * 0.04)

            Ellipse()
                .fill(bellyColor)
                .frame(width: size * 0.42, height: size * 0.62)
                .offset(x: -size * 0.10, y: size * 0.08)

            BeakShape()
                .fill(beakColor)
                .frame(width: size * 0.28, height: size * 0.20)
                .overlay(
                    BeakShape()
                        .fill(beakHighlight)
                        .frame(width: size * 0.10, height: size * 0.18)
                        .offset(x: -size * 0.06)
                )
                .offset(x: -size * 0.34, y: -size * 0.06)

            Circle()
                .fill(bellyColor)
                .frame(width: size * 0.09)
                .overlay(
                    Circle()
                        .fill(bodyColor)
                        .frame(width: size * 0.045)
                )
                .offset(x: -size * 0.14, y: -size * 0.20)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 32) {
        PuffinMark(size: 200)
        PuffinMark(size: 80)
        PuffinMark(size: 32)
    }
    .padding(48)
    .background(Color.pinCream)
}

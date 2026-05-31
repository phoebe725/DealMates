import SwiftUI

/// Front-facing geometric puffin — the "looking right at you" pose. Use for the
/// app icon, an onboarding hero, or a small mascot accent on empty states when
/// the painterly illustration would be overkill.
struct PuffinPortrait: View {
    var size: CGFloat = 120
    var bodyColor: Color = .pinInk
    var faceColor: Color = .pinCream
    var beakColor: Color = .pinClay
    var beakAccent: Color = .pinPeach

    var body: some View {
        ZStack {
            Circle()
                .fill(bodyColor)
                .frame(width: size, height: size)

            Ellipse()
                .fill(faceColor)
                .frame(width: size * 0.68, height: size * 0.78)
                .offset(y: size * 0.06)

            HStack(spacing: size * 0.30) {
                Circle().fill(bodyColor).frame(width: size * 0.07)
                Circle().fill(bodyColor).frame(width: size * 0.07)
            }
            .offset(y: -size * 0.04)

            ZStack {
                Triangle()
                    .fill(beakColor)
                    .frame(width: size * 0.24, height: size * 0.24)
                Triangle()
                    .fill(beakAccent)
                    .frame(width: size * 0.10, height: size * 0.14)
                    .offset(y: -size * 0.04)
            }
            .rotationEffect(.degrees(180))
            .offset(y: size * 0.14)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 32) {
        PuffinPortrait(size: 200)
        PuffinPortrait(size: 96)
        PuffinPortrait(size: 40)
    }
    .padding(48)
    .background(Color.pinCream)
}

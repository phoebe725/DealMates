import SwiftUI

/// Down-pointing triangle, used inside the puffin beak. Anchored so it draws
/// cleanly inside its bounding rect — composes well with rotation.
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

/// Side-profile beak silhouette. Wider on the right (the tip), pinched on the
/// left (where it meets the face).
struct BeakShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.30),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.30),
            control: CGPoint(x: rect.maxX + rect.width * 0.15, y: rect.midY)
        )
        p.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        p.closeSubpath()
        return p
    }
}

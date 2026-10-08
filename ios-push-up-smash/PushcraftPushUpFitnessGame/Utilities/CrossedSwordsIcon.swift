import SwiftUI

/// A single sword used by `CrossedSwordsIcon`, drawn in a unit square with the
/// blade pointing up: pointed blade, crossguard, handle and pommel.
private struct SwordShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()

        // Blade with pointed tip
        p.move(to: CGPoint(x: 0.5, y: 0.0))
        p.addLine(to: CGPoint(x: 0.565, y: 0.12))
        p.addLine(to: CGPoint(x: 0.565, y: 0.56))
        p.addLine(to: CGPoint(x: 0.435, y: 0.56))
        p.addLine(to: CGPoint(x: 0.435, y: 0.12))
        p.closeSubpath()

        // Crossguard
        p.addRect(CGRect(x: 0.33, y: 0.56, width: 0.34, height: 0.07))

        // Handle
        p.addRect(CGRect(x: 0.455, y: 0.63, width: 0.09, height: 0.24))

        // Pommel
        p.addEllipse(in: CGRect(x: 0.43, y: 0.87, width: 0.14, height: 0.14))

        return p
    }
}

/// Crossed swords glyph (no SF Symbol exists) used across the Battles UI.
struct CrossedSwordsIcon: View {
    var color: Color = Theme.mist

    var body: some View {
        ZStack {
            SwordShape().fill(color).rotationEffect(.degrees(45))
            SwordShape().fill(color).rotationEffect(.degrees(-45))
        }
    }
}

#Preview {
    CrossedSwordsIcon()
        .frame(width: 40, height: 40)
        .padding()
        .background(Color(hex: 0x0B1426))
}

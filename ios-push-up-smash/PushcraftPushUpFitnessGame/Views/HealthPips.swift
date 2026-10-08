import SwiftUI

/// Gold health pips under the block — filled = remaining hits.
struct HealthPips: View {
    let total: Int
    let remaining: Int

    private var size: CGFloat {
        switch total {
        case ...5: 20
        case ...7: 17
        default: 14
        }
    }

    var body: some View {
        HStack(spacing: size * 0.34) {
            ForEach(0..<total, id: \.self) { index in
                Pip(isFilled: index < remaining, size: size)
            }
        }
    }
}

private struct Pip: View {
    let isFilled: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.45))
            Circle()
                .strokeBorder(Color.white.opacity(0.45), lineWidth: 2)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0xFFE680), Theme.gold, Color(hex: 0xE08A00)],
                        center: UnitPoint(x: 0.38, y: 0.32),
                        startRadius: 0,
                        endRadius: size * 0.6
                    )
                )
                .overlay(Circle().strokeBorder(Color(hex: 0x9A5A00), lineWidth: 1.5))
                .shadow(color: Theme.gold.opacity(0.8), radius: 6)
                .scaleEffect(isFilled ? 1 : 0.2)
                .opacity(isFilled ? 1 : 0)
        }
        .frame(width: size, height: size)
        .scaleEffect(isFilled ? 1 : 0.86)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isFilled)
    }
}

import SwiftUI

private struct BlockShake {
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rotation: Double = 0
    var scale: CGFloat = 1
    var flash: Double = 0
}

/// The floating block: material texture, neon rim, accumulating cracks,
/// charge glow and a punchy shake + white flash on every hit.
struct BlockView: View {
    let tier: BlockTier
    let seed: UInt64
    let damage: Double
    let charge: Double
    let isCharged: Bool
    let hitTrigger: Int
    var side: CGFloat = 150

    private var crackCount: Int {
        damage <= 0 ? 0 : Int((damage * 8).rounded(.up)) + 1
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: side * 0.13, style: .continuous)
        let glow = isCharged ? Theme.gold : tier.accent

        Color.clear
            .frame(width: side, height: side)
            .overlay {
                Image(tier.textureName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false)
            }
            .overlay(Color.black.opacity(damage * 0.2))
            .overlay {
                CrackLayer(cracks: CrackGenerator.make(seed: seed, count: crackCount))
            }
            .overlay {
                Image(systemName: "exclamationmark")
                    .font(.system(size: side * 0.42, weight: .black))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.55), radius: 0, x: 2, y: 3)
                    .shadow(color: glow.opacity(0.6 * charge), radius: 10)
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.4), .clear, .black.opacity(0.45)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 6
                )
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(glow, lineWidth: 3)
                    .shadow(color: glow, radius: 6)
            }
            .overlay {
                shape.strokeBorder(.white.opacity(0.7), lineWidth: 1)
                    .padding(1.5)
            }
            .background {
                shape.fill(glow.opacity(0.25 + 0.55 * charge))
                    .blur(radius: 14 + 18 * charge)
                    .scaleEffect(1 + 0.12 * charge)
            }
            .keyframeAnimator(initialValue: BlockShake(), trigger: hitTrigger) { content, value in
                content
                    .overlay(shape.fill(.white).opacity(value.flash).allowsHitTesting(false))
                    .scaleEffect(value.scale)
                    .rotationEffect(.degrees(value.rotation))
                    .offset(x: value.x, y: value.y)
            } keyframes: { _ in
                KeyframeTrack(\.y) {
                    SpringKeyframe(-30, duration: 0.07)
                    SpringKeyframe(6, duration: 0.14)
                    SpringKeyframe(0, duration: 0.3, spring: .bouncy)
                }
                KeyframeTrack(\.x) {
                    LinearKeyframe(-12, duration: 0.05)
                    LinearKeyframe(11, duration: 0.06)
                    LinearKeyframe(-8, duration: 0.06)
                    LinearKeyframe(5, duration: 0.06)
                    LinearKeyframe(-2, duration: 0.05)
                    LinearKeyframe(0, duration: 0.05)
                }
                KeyframeTrack(\.rotation) {
                    LinearKeyframe(-5, duration: 0.05)
                    LinearKeyframe(4, duration: 0.07)
                    LinearKeyframe(-2, duration: 0.07)
                    SpringKeyframe(0, duration: 0.2)
                }
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.14, duration: 0.07)
                    SpringKeyframe(0.95, duration: 0.12)
                    SpringKeyframe(1, duration: 0.25, spring: .bouncy)
                }
                KeyframeTrack(\.flash) {
                    MoveKeyframe(0.95)
                    LinearKeyframe(0, duration: 0.24)
                }
            }
            .animation(.easeOut(duration: 0.15), value: charge)
    }
}

private struct CrackLayer: View {
    let cracks: [Crack]

    var body: some View {
        Canvas { context, size in
            for crack in cracks {
                var path = Path()
                for (index, point) in crack.points.enumerated() {
                    let p = CGPoint(x: point.x * size.width, y: point.y * size.height)
                    if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                let style = StrokeStyle(lineWidth: crack.width, lineCap: .round, lineJoin: .miter)
                context.stroke(
                    path.offsetBy(dx: 1.2, dy: 1.4),
                    with: .color(.white.opacity(0.35)),
                    style: StrokeStyle(lineWidth: crack.width * 0.5, lineCap: .round, lineJoin: .miter)
                )
                context.stroke(path, with: .color(Color(hex: 0x0B0F14).opacity(0.9)), style: style)
            }
        }
        .allowsHitTesting(false)
    }
}

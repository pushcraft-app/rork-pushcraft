import SwiftUI

/// Full-screen particle layer: hit beams, shock rings, debris and the coin burst.
/// Draws in global coordinates, so it must cover the whole screen.
struct EffectsOverlay: View {
    let engine: GameEngine

    var body: some View {
        TimelineView(.animation(paused: !engine.hasActiveEffects)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, _ in
                drawBeams(&context, now: now)
                drawRings(&context, now: now)
                drawShards(&context, now: now)
                drawCoins(&context, now: now)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawBeams(_ context: inout GraphicsContext, now: Double) {
        for beam in engine.beams {
            let t = (now - beam.start) / HitBeam.lifetime
            guard t >= 0, t < 1 else { continue }
            var path = Path()
            path.move(to: beam.from)
            path.addLine(to: beam.to)
            let fade = 1 - t
            var glow = context
            glow.addFilter(.blur(radius: 8))
            glow.stroke(path, with: .color(beam.color.opacity(0.8 * fade)), style: StrokeStyle(lineWidth: 18 * fade, lineCap: .round))
            context.stroke(path, with: .color(.white.opacity(fade)), style: StrokeStyle(lineWidth: 5 * fade, lineCap: .round))
        }
    }

    private func drawRings(_ context: inout GraphicsContext, now: Double) {
        for ring in engine.rings {
            let t = (now - ring.start) / ShockRing.lifetime
            guard t >= 0, t < 1 else { continue }
            let eased = 1 - pow(1 - t, 3)
            let maxRadius = ring.isBig ? 260.0 : 90 + 70 * ring.power
            let radius = 24 + (maxRadius - 24) * eased
            let squash = ring.isBig ? 1.0 : 0.42
            let rect = CGRect(
                x: ring.origin.x - radius,
                y: ring.origin.y - radius * squash,
                width: radius * 2,
                height: radius * 2 * squash
            )
            let fade = 1 - t
            var glow = context
            glow.addFilter(.blur(radius: 6))
            glow.stroke(Path(ellipseIn: rect), with: .color(ring.color.opacity(fade)), lineWidth: 12 * fade)
            context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.9 * fade)), lineWidth: 3.5 * fade + 0.5)
        }
    }

    private func drawShards(_ context: inout GraphicsContext, now: Double) {
        for burst in engine.shardBursts {
            let t = now - burst.start
            guard t >= 0, t < ShardBurst.lifetime else { continue }
            let fade = 1 - pow(t / ShardBurst.lifetime, 2)
            for shard in burst.shards {
                let x = burst.origin.x + shard.vx * t
                let y = burst.origin.y + shard.vy * t + 0.5 * 1500 * t * t
                var local = context
                local.translateBy(x: x, y: y)
                local.rotate(by: .radians(shard.rotation + shard.spin * t))
                local.opacity = fade
                let path = polygon(sides: shard.sides, radius: shard.size / 2)
                local.fill(path, with: .color(burst.color))
                local.fill(path, with: .color(.black.opacity(shard.shade)))
                local.stroke(path, with: .color(.white.opacity(0.35)), lineWidth: 1)
            }
        }
    }

    private func drawCoins(_ context: inout GraphicsContext, now: Double) {
        guard !engine.coinBursts.isEmpty else { return }
        let image = context.resolve(Image("gold_coin_star"))
        for burst in engine.coinBursts {
            let t = now - burst.start
            for coin in burst.coins {
                guard let state = burst.state(of: coin, at: t) else { continue }
                let spin = max(abs(cos(coin.spin * t)), 0.18)
                var local = context
                local.translateBy(x: state.point.x, y: state.point.y)
                local.scaleBy(x: spin, y: 1)
                let s = state.size
                var glow = local
                glow.addFilter(.blur(radius: 6))
                glow.fill(
                    Path(ellipseIn: CGRect(x: -s * 0.55, y: -s * 0.55, width: s * 1.1, height: s * 1.1)),
                    with: .color(Theme.gold.opacity(0.6))
                )
                local.draw(image, in: CGRect(x: -s / 2, y: -s / 2, width: s, height: s))
            }
        }
    }

    private func polygon(sides: Int, radius: Double) -> Path {
        var path = Path()
        for index in 0..<sides {
            let angle = Double(index) / Double(sides) * 2 * Double.pi
            let r = radius * (index % 2 == 0 ? 1 : 0.7)
            let point = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

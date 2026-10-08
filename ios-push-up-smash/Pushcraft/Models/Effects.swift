import SwiftUI

/// Coins that burst out of a broken block and then fly into the COINS counter.
struct CoinBurst: Identifiable {
    struct Coin {
        let angle: Double
        let speed: Double
        let spin: Double
        /// Seconds after `start` when the coin leaves the burst and homes in on the counter.
        let flyStart: Double
        var arrival: Double { flyStart + CoinBurst.flyDuration }
    }

    static let flyDuration = 0.42
    static let gravity = 1300.0

    let id: Int
    let start: Double
    let origin: CGPoint
    let target: CGPoint
    let coins: [Coin]

    var end: Double { start + (coins.map(\.arrival).max() ?? 1) }

    static func make(id: Int, start: Double, origin: CGPoint, target: CGPoint, count: Int) -> CoinBurst {
        let coins = (0..<count).map { index in
            Coin(
                angle: Double.random(in: (-Double.pi + 0.35)...(-0.35)),
                speed: Double.random(in: 360...640),
                spin: Double.random(in: 9...16),
                flyStart: 0.5 + Double(index) * 0.04
            )
        }
        return CoinBurst(id: id, start: start, origin: origin, target: target, coins: coins)
    }

    /// Position and size of a coin `t` seconds after the burst started, or nil once it has arrived.
    func state(of coin: Coin, at t: Double) -> (point: CGPoint, size: CGFloat)? {
        guard t >= 0, t < coin.arrival else { return nil }
        let vx = cos(coin.angle) * coin.speed
        let vy = sin(coin.angle) * coin.speed
        func ballistic(_ time: Double) -> CGPoint {
            CGPoint(
                x: origin.x + vx * time * 0.9,
                y: origin.y + vy * time + 0.5 * Self.gravity * time * time
            )
        }
        if t < coin.flyStart {
            return (ballistic(t), 30)
        }
        let p0 = ballistic(coin.flyStart)
        let u = (t - coin.flyStart) / Self.flyDuration
        let eased = u * u
        let control = CGPoint(x: (p0.x + target.x) / 2 + (p0.x - target.x) * 0.2, y: min(p0.y, target.y) - 60)
        let a = 1 - eased
        let point = CGPoint(
            x: a * a * p0.x + 2 * a * eased * control.x + eased * eased * target.x,
            y: a * a * p0.y + 2 * a * eased * control.y + eased * eased * target.y
        )
        return (point, 30 - 10 * eased)
    }
}

/// Block debris.
struct ShardBurst: Identifiable {
    struct Shard {
        let vx: Double
        let vy: Double
        let size: Double
        let rotation: Double
        let spin: Double
        let sides: Int
        let shade: Double
    }

    static let lifetime = 1.1
    let id: Int
    let start: Double
    let origin: CGPoint
    let color: Color
    let shards: [Shard]

    static func make(id: Int, start: Double, origin: CGPoint, color: Color, count: Int) -> ShardBurst {
        let shards = (0..<count).map { _ in
            let angle = Double.random(in: 0...(2 * Double.pi))
            let speed = Double.random(in: 240...720)
            return Shard(
                vx: cos(angle) * speed,
                vy: sin(angle) * speed - 260,
                size: Double.random(in: 10...28),
                rotation: Double.random(in: 0...(2 * Double.pi)),
                spin: Double.random(in: -12...12),
                sides: Int.random(in: 3...4),
                shade: Double.random(in: 0...0.35)
            )
        }
        return ShardBurst(id: id, start: start, origin: origin, color: color, shards: shards)
    }
}

/// Shock ring fired from the bottom of the block on every hit.
struct ShockRing: Identifiable {
    static let lifetime = 0.5
    let id: Int
    let start: Double
    let origin: CGPoint
    let power: Double
    let color: Color
    let isBig: Bool
}

struct PayoutPopup: Identifiable {
    let id: Int
    let amount: Int
}

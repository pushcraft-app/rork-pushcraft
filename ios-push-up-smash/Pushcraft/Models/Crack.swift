import CoreGraphics
import Foundation

/// A single crack polyline in unit block coordinates (0...1, top-left origin).
struct Crack: Identifiable {
    let id: Int
    let points: [CGPoint]
    let width: CGFloat
}

/// Deterministic crack pattern generator. Cracks start where the head strikes (bottom center)
/// and spread upward, later cracks branch off earlier ones or bite in from the edges.
enum CrackGenerator {
    static func make(seed: UInt64, count: Int) -> [Crack] {
        var rng = SeededGenerator(seed: seed)
        var cracks: [Crack] = []
        var anchors: [CGPoint] = []

        for index in 0..<count {
            var start: CGPoint
            var angle: Double

            if index == 0 || anchors.isEmpty {
                start = CGPoint(x: Double.random(in: 0.42...0.58, using: &rng), y: 1.0)
                angle = -Double.pi / 2 + Double.random(in: -0.3...0.3, using: &rng)
            } else if index % 3 == 2 {
                switch Int.random(in: 0...2, using: &rng) {
                case 0:
                    start = CGPoint(x: 0, y: Double.random(in: 0.2...0.8, using: &rng))
                    angle = Double.random(in: -0.6...0.6, using: &rng)
                case 1:
                    start = CGPoint(x: 1, y: Double.random(in: 0.2...0.8, using: &rng))
                    angle = Double.pi + Double.random(in: -0.6...0.6, using: &rng)
                default:
                    start = CGPoint(x: Double.random(in: 0.2...0.8, using: &rng), y: 0)
                    angle = Double.pi / 2 + Double.random(in: -0.6...0.6, using: &rng)
                }
            } else {
                start = anchors[Int.random(in: 0..<anchors.count, using: &rng)]
                angle = Double.random(in: -Double.pi...Double.pi, using: &rng)
            }

            var points: [CGPoint] = [start]
            var point = start
            let segments = Int.random(in: 4...7, using: &rng)
            for _ in 0..<segments {
                let length = Double.random(in: 0.07...0.13, using: &rng)
                angle += Double.random(in: -0.55...0.55, using: &rng)
                point = CGPoint(
                    x: min(max(point.x + cos(angle) * length, 0.02), 0.98),
                    y: min(max(point.y + sin(angle) * length, 0.02), 0.98)
                )
                points.append(point)
            }
            anchors.append(contentsOf: points.dropFirst())
            let width: CGFloat = index == 0 ? 4.5 : CGFloat(Double.random(in: 2.4...3.8, using: &rng))
            cracks.append(Crack(id: index, points: points, width: width))
        }
        return cracks
    }
}

/// SplitMix64 — small, fast, deterministic RNG.
nonisolated struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

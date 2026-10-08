import SwiftUI

/// Block material ladder: CRATE → STONE → ALLOY → GOLD.
enum BlockTier: Int, CaseIterable {
    case crate, stone, alloy, gold

    var name: String {
        switch self {
        case .crate: "CRATE"
        case .stone: "STONE"
        case .alloy: "ALLOY"
        case .gold: "GOLD"
        }
    }

    var baseHealth: Int {
        switch self {
        case .crate: 3
        case .stone: 5
        case .alloy: 7
        case .gold: 9
        }
    }

    var basePayout: Int {
        switch self {
        case .crate: 10
        case .stone: 18
        case .alloy: 28
        case .gold: 40
        }
    }

    var textureName: String {
        switch self {
        case .crate: "wooden_crate_front"
        case .stone: "slate_stone_block_tile"
        case .alloy: "steel_armor_tile"
        case .gold: "gold_treasure_block"
        }
    }

    var accent: Color {
        switch self {
        case .crate: Color(hex: 0xFF9A3C)
        case .stone: Theme.cyan
        case .alloy: Color(hex: 0xA98BFF)
        case .gold: Color(hex: 0xFFD34D)
        }
    }

    var shardColor: Color {
        switch self {
        case .crate: Color(hex: 0xB86B2E)
        case .stone: Color(hex: 0x5E8497)
        case .alloy: Color(hex: 0x8A8FA8)
        case .gold: Color(hex: 0xF2B632)
        }
    }

    static func forLevel(_ level: Int) -> BlockTier {
        BlockTier(rawValue: min(max(level, 0), BlockTier.gold.rawValue)) ?? .gold
    }
}

/// Curated per-session block orders. Every session opens with an easy crate;
/// the rest draw from a few hand-picked sequences — stone and alloy
/// occasionally swap, and some sessions spring an early gold bonus. Toughness
/// and payouts stay tied to the material, so every order totals the same reps.
enum BlockPlan {
    static let sequences: [[BlockTier]] = [
        [.crate, .stone, .alloy, .gold],
        [.crate, .stone, .gold, .alloy],
        [.crate, .alloy, .stone, .gold],
        [.crate, .gold, .stone, .alloy]
    ]

    static func random() -> [BlockTier] {
        sequences.randomElement() ?? sequences[0]
    }

    /// The tier for a block position; endless gold once the plan runs out.
    static func tier(at level: Int, plan: [BlockTier]) -> BlockTier {
        guard level >= 0 else { return .crate }
        return level < plan.count ? plan[level] : .gold
    }
}

/// Concrete block stats for a given level. After GOLD, blocks keep getting tougher and richer.
struct BlockSpec: Equatable {
    let level: Int
    let tier: BlockTier
    let health: Int
    let payout: Int

    static func make(level: Int) -> BlockSpec {
        make(level: level, tier: BlockTier.forLevel(level))
    }

    static func make(level: Int, tier: BlockTier) -> BlockSpec {
        let extra = max(0, level - BlockTier.gold.rawValue)
        return BlockSpec(
            level: level,
            tier: tier,
            health: tier.baseHealth + min(extra, 2) * 2,
            payout: tier.basePayout + extra * 10
        )
    }
}

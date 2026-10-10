package com.tinochiwara.pushcraft.game

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import com.tinochiwara.pushcraft.R
import com.tinochiwara.pushcraft.ui.theme.Pc
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

/** Block material ladder: CRATE → STONE → ALLOY → GOLD. */
enum class BlockTier(val label: String, val baseHealth: Int, val basePayout: Int, val texture: Int, val accent: Color, val shardColor: Color) {
    Crate("CRATE", 3, 10, R.drawable.wooden_crate_front, Color(0xFFFF9A3C), Color(0xFFB86B2E)),
    Stone("STONE", 5, 18, R.drawable.slate_stone_block_tile, Pc.cyan, Color(0xFF5E8497)),
    Alloy("ALLOY", 7, 28, R.drawable.steel_armor_tile, Color(0xFFA98BFF), Color(0xFF8A8FA8)),
    Gold("GOLD", 9, 40, R.drawable.gold_treasure_block, Color(0xFFFFD34D), Color(0xFFF2B632))
}

object BlockPlan {
    val sequences = listOf(
        listOf(BlockTier.Crate, BlockTier.Stone, BlockTier.Alloy, BlockTier.Gold),
        listOf(BlockTier.Crate, BlockTier.Stone, BlockTier.Gold, BlockTier.Alloy),
        listOf(BlockTier.Crate, BlockTier.Alloy, BlockTier.Stone, BlockTier.Gold),
        listOf(BlockTier.Crate, BlockTier.Gold, BlockTier.Stone, BlockTier.Alloy)
    )

    fun random(): List<BlockTier> = sequences.random()

    fun tier(level: Int, plan: List<BlockTier>): BlockTier = when {
        level < 0 -> BlockTier.Crate
        level < plan.size -> plan[level]
        else -> BlockTier.Gold
    }
}

data class BlockSpec(val level: Int, val tier: BlockTier, val health: Int, val payout: Int) {
    companion object {
        fun make(level: Int, tier: BlockTier): BlockSpec {
            val extra = maxOf(0, level - BlockTier.Gold.ordinal)
            return BlockSpec(level, tier, tier.baseHealth + minOf(extra, 2) * 2, tier.basePayout + extra * 10)
        }
    }
}

/** A crack polyline in unit block coordinates. */
data class Crack(val points: List<Offset>, val width: Float)

/** Deterministic crack pattern generator (cracks spread up from the strike point). */
object CrackGenerator {
    fun make(seed: Long, count: Int): List<Crack> {
        val rng = Random(seed)
        fun r(a: Double, b: Double) = a + rng.nextDouble() * (b - a)
        val cracks = mutableListOf<Crack>()
        val anchors = mutableListOf<Offset>()
        for (index in 0 until count) {
            var start: Offset
            var angle: Double
            if (index == 0 || anchors.isEmpty()) {
                start = Offset(r(0.42, 0.58).toFloat(), 1f)
                angle = -Math.PI / 2 + r(-0.3, 0.3)
            } else if (index % 3 == 2) {
                when (rng.nextInt(3)) {
                    0 -> { start = Offset(0f, r(0.2, 0.8).toFloat()); angle = r(-0.6, 0.6) }
                    1 -> { start = Offset(1f, r(0.2, 0.8).toFloat()); angle = Math.PI + r(-0.6, 0.6) }
                    else -> { start = Offset(r(0.2, 0.8).toFloat(), 0f); angle = Math.PI / 2 + r(-0.6, 0.6) }
                }
            } else {
                start = anchors[rng.nextInt(anchors.size)]
                angle = r(-Math.PI, Math.PI)
            }
            val points = mutableListOf(start)
            var p = start
            repeat(rng.nextInt(4, 8)) {
                val len = r(0.07, 0.13)
                angle += r(-0.55, 0.55)
                p = Offset(
                    (p.x + cos(angle) * len).toFloat().coerceIn(0.02f, 0.98f),
                    (p.y + sin(angle) * len).toFloat().coerceIn(0.02f, 0.98f)
                )
                points.add(p)
            }
            anchors.addAll(points.drop(1))
            cracks.add(Crack(points, if (index == 0) 4.5f else r(2.4, 3.8).toFloat()))
        }
        return cracks
    }
}

// MARK: - Effects

data class CoinBurst(val id: Int, val start: Long, val origin: Offset, val target: Offset, val coins: List<Coin>) {
    data class Coin(val angle: Double, val speed: Double, val spin: Double, val flyStart: Double) {
        val arrival: Double get() = flyStart + FLY_DURATION
    }

    val endMs: Long get() = start + ((coins.maxOfOrNull { it.arrival } ?: 1.0) * 1000).toLong()

    /** Position and size `t` seconds after the burst started, or null once arrived. */
    fun state(coin: Coin, t: Double): Pair<Offset, Float>? {
        if (t < 0 || t >= coin.arrival) return null
        val vx = cos(coin.angle) * coin.speed
        val vy = sin(coin.angle) * coin.speed
        fun ballistic(time: Double) = Offset(
            (origin.x + vx * time * 0.9).toFloat(),
            (origin.y + vy * time + 0.5 * GRAVITY * time * time).toFloat()
        )
        if (t < coin.flyStart) return ballistic(t) to 30f
        val p0 = ballistic(coin.flyStart)
        val u = (t - coin.flyStart) / FLY_DURATION
        val e = (u * u).toFloat()
        val control = Offset((p0.x + target.x) / 2 + (p0.x - target.x) * 0.2f, minOf(p0.y, target.y) - 60f)
        val a = 1 - e
        return Offset(
            a * a * p0.x + 2 * a * e * control.x + e * e * target.x,
            a * a * p0.y + 2 * a * e * control.y + e * e * target.y
        ) to (30f - 10f * e)
    }

    companion object {
        const val FLY_DURATION = 0.42
        const val GRAVITY = 1300.0

        fun make(id: Int, start: Long, origin: Offset, target: Offset, count: Int) = CoinBurst(
            id, start, origin, target,
            (0 until count).map { i ->
                Coin(
                    angle = Random.nextDouble(-Math.PI + 0.35, -0.35),
                    speed = Random.nextDouble(360.0, 640.0),
                    spin = Random.nextDouble(9.0, 16.0),
                    flyStart = 0.5 + i * 0.04
                )
            }
        )
    }
}

data class ShardBurst(val id: Int, val start: Long, val origin: Offset, val color: Color, val shards: List<Shard>) {
    data class Shard(val vx: Double, val vy: Double, val size: Double, val rotation: Double, val spin: Double, val sides: Int, val shade: Double)

    companion object {
        const val LIFETIME = 1.1
        fun make(id: Int, start: Long, origin: Offset, color: Color, count: Int) = ShardBurst(
            id, start, origin, color,
            (0 until count).map {
                val a = Random.nextDouble(0.0, 2 * Math.PI)
                val s = Random.nextDouble(240.0, 720.0)
                Shard(cos(a) * s, sin(a) * s - 260, Random.nextDouble(10.0, 28.0), Random.nextDouble(0.0, 2 * Math.PI),
                    Random.nextDouble(-12.0, 12.0), Random.nextInt(3, 5), Random.nextDouble(0.0, 0.35))
            }
        )
    }
}

data class ShockRing(val id: Int, val start: Long, val origin: Offset, val power: Double, val color: Color, val isBig: Boolean) {
    companion object { const val LIFETIME = 0.5 }
}

data class HitBeam(val id: Int, val start: Long, val from: Offset, val to: Offset, val color: Color) {
    companion object { const val LIFETIME = 0.32 }
}

data class PayoutPopup(val id: Int, val amount: Int)

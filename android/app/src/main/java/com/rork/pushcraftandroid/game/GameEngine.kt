package com.rork.pushcraftandroid.game

import android.os.SystemClock
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import com.rork.pushcraftandroid.data.Haptics
import com.rork.pushcraftandroid.data.SoundService
import com.rork.pushcraftandroid.model.Exercise
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.random.Random

enum class CameraStatus { Idle, Running, Denied, NoCamera, Failed }
enum class BlockPhase { Dropping, Idle, Shattered }

/** Owns the game: pose → reps → block damage → payouts. Compose snapshot state. */
class GameEngine(val exercise: Exercise = Exercise.PushUps, firstBlockHealth: Int? = null) {
    companion object { const val COINS_PER_BURST = 14 }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val detector = RepDetector(exercise)
    private val tierPlan = if (firstBlockHealth == null) BlockPlan.random() else BlockPlan.sequences[0]

    var cameraStatus by mutableStateOf(CameraStatus.Idle)
    var reps by mutableIntStateOf(0); private set
    var coins by mutableIntStateOf(0); private set
    var displayedCoins by mutableIntStateOf(0); private set
    var spec by mutableStateOf(
        if (firstBlockHealth != null) BlockSpec(0, BlockTier.Crate, firstBlockHealth, BlockTier.Crate.basePayout)
        else BlockSpec.make(0, tierPlan[0])
    ); private set
    var health by mutableIntStateOf(spec.health); private set
    var blockId by mutableIntStateOf(0); private set
    var blockSeed by mutableLongStateOf(7L); private set
    var blockPhase by mutableStateOf(BlockPhase.Dropping); private set
    var hitCount by mutableIntStateOf(0); private set
    var smashCount by mutableIntStateOf(0); private set
    var tracking by mutableStateOf(RepTracking.Initial); private set
    var cue by mutableStateOf(CoachCue.GetInFrame); private set
    var pose by mutableStateOf(DisplayPose.Empty); private set
    var coinBursts by mutableStateOf(listOf<CoinBurst>()); private set
    var shardBursts by mutableStateOf(listOf<ShardBurst>()); private set
    var rings by mutableStateOf(listOf<ShockRing>()); private set
    var beams by mutableStateOf(listOf<HitBeam>()); private set
    var payout by mutableStateOf<PayoutPopup?>(null); private set

    var isAcceptingReps = true
    var onRep: (() -> Unit)? = null

    // Layout in root coordinates
    var screenSize = Size.Zero
    var blockFrame = Rect.Zero
    var coinTarget = Offset.Zero

    val hitsTaken: Int get() = spec.health - health
    val hasActiveEffects: Boolean get() = coinBursts.isNotEmpty() || shardBursts.isNotEmpty() || rings.isNotEmpty() || beams.isNotEmpty()

    private var effectId = 0
    private var generation = 0
    private var isCelebrating = false
    private var hasStarted = false
    private val jointSeen = mutableMapOf<Joint, Double>()

    fun start() {
        if (!hasStarted) {
            hasStarted = true
            land(450)
        }
    }

    fun dispose() = scope.cancel()

    /** Called on the main thread with each analysed frame. */
    fun handle(frame: PoseFrame) {
        val now = SystemClock.elapsedRealtime() / 1000.0
        val event = detector.process(frame, now)
        if (detector.state != tracking) tracking = detector.state
        updatePose(frame, now)
        updateCue()
        if (event.justCharged) Haptics.charged()
        if (event.repCompleted) registerRep(event.power)
    }

    private fun updatePose(frame: PoseFrame, now: Double) {
        val joints = mutableMapOf<Joint, Offset>()
        for ((joint, p) in frame.joints) {
            jointSeen[joint] = now
            val old = pose.joints[joint]
            joints[joint] = if (old != null) Offset(old.x + (p.x - old.x) * 0.65f, old.y + (p.y - old.y) * 0.65f) else p
        }
        for ((joint, p) in pose.joints) {
            if (joints[joint] == null && now - (jointSeen[joint] ?: 0.0) < 0.25) joints[joint] = p
        }
        pose = DisplayPose(joints, frame.imageSize)
    }

    private fun updateCue() {
        val next = if (isCelebrating) CoachCue.Smashed else when (tracking.phase) {
            RepPhase.Searching -> CoachCue.GetInFrame
            RepPhase.Calibrating -> CoachCue.HoldTop
            RepPhase.Top, RepPhase.Charging -> CoachCue.GoDown
            RepPhase.Charged -> CoachCue.SmashIt
        }
        if (next != cue) cue = next
    }

    private fun registerRep(power: Double) {
        if (!isAcceptingReps) return
        reps += 1
        if (blockPhase == BlockPhase.Idle && health > 0) hit(power)
        onRep?.invoke()
    }

    private fun now() = SystemClock.uptimeMillis()

    private fun hit(power: Double) {
        health -= 1
        hitCount += 1
        val impact = Offset(blockFrame.center.x, blockFrame.bottom)
        SoundService.play(SoundService.Effect.Hit, (1.12 - 0.28 * power).toFloat(), 1f)
        Haptics.hit(power)
        rings = rings + ShockRing(nextId(), now(), impact, power, spec.tier.accent, false)
        headPoint()?.let { beams = beams + HitBeam(nextId(), now(), it, impact, spec.tier.accent) }
        after(600) { prune() }
        if (health <= 0) smash()
    }

    private fun smash() {
        val gen = generation
        val amount = spec.payout
        val center = blockFrame.center
        blockPhase = BlockPhase.Shattered
        isCelebrating = true
        smashCount += 1
        coins += amount
        updateCue()
        SoundService.play(SoundService.Effect.Shatter)
        Haptics.smash()
        val t = now()
        shardBursts = shardBursts + ShardBurst.make(nextId(), t, center, spec.tier.shardColor, 22)
        rings = rings + ShockRing(nextId(), t, center, 1.0, spec.tier.accent, true)
        payout = PayoutPopup(nextId(), amount)
        val burst = CoinBurst.make(nextId(), t, center, coinTarget, COINS_PER_BURST)
        coinBursts = coinBursts + burst
        val perCoin = amount / COINS_PER_BURST
        val remainder = amount % COINS_PER_BURST
        burst.coins.forEachIndexed { index, coin ->
            val share = perCoin + if (index < remainder) 1 else 0
            after((coin.arrival * 1000).toLong(), gen) {
                displayedCoins += share
                if (index % 2 == 0) Haptics.coinTick()
            }
        }
        after(420, gen) { SoundService.play(SoundService.Effect.Coins) }
        after(1250, gen) { payout = null }
        after(burst.endMs - t + 100, gen) {
            displayedCoins = coins
            prune()
        }
        after(1450, gen) {
            isCelebrating = false
            spawn(spec.level + 1)
            updateCue()
        }
    }

    private fun spawn(level: Int) {
        spec = BlockSpec.make(level, BlockPlan.tier(level, tierPlan))
        health = spec.health
        blockId += 1
        blockSeed = Random.nextLong()
        blockPhase = BlockPhase.Dropping
        SoundService.play(SoundService.Effect.Drop, if (spec.tier.ordinal >= BlockTier.Alloy.ordinal) 0.85f else 1f)
        land(380)
    }

    private fun land(delayMs: Long) {
        after(delayMs, generation) {
            if (blockPhase == BlockPhase.Dropping) {
                blockPhase = BlockPhase.Idle
                Haptics.land()
            }
        }
    }

    private fun headPoint(): Offset? {
        val p = pose.joints[Joint.Nose] ?: pose.joints[Joint.Neck] ?: return null
        return PoseMapper.map(p, pose.imageSize, screenSize)
    }

    private fun nextId(): Int = ++effectId

    private fun after(ms: Long, gen: Int = generation, action: () -> Unit) {
        scope.launch {
            delay(maxOf(ms, 0))
            if (generation == gen) action()
        }
    }

    private fun prune() {
        val n = now()
        rings = rings.filter { n - it.start < (ShockRing.LIFETIME * 1000 + 50) }
        beams = beams.filter { n - it.start < (HitBeam.LIFETIME * 1000 + 50) }
        shardBursts = shardBursts.filter { n - it.start < (ShardBurst.LIFETIME * 1000 + 50) }
        coinBursts = coinBursts.filter { n < it.endMs + 50 }
    }
}

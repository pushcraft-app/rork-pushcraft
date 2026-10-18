package com.tinochiwara.pushcraft.game

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import com.tinochiwara.pushcraft.model.Exercise
import kotlin.math.abs

/** The body joints we track (ML Kit landmarks mapped to the iOS joint set). */
enum class Joint(val isFace: Boolean = false) {
    Nose(true), LeftEye(true), RightEye(true), LeftEar(true), RightEar(true),
    Neck, LeftShoulder, RightShoulder, LeftElbow, RightElbow, LeftWrist, RightWrist,
    Root, LeftHip, RightHip, LeftKnee, RightKnee, LeftAnkle, RightAnkle
}

/** One analysed frame: normalized (0..1, top-left) joints in the mirrored image. */
data class PoseFrame(val joints: Map<Joint, Offset>, val imageSize: Size)

data class DisplayPose(val joints: Map<Joint, Offset>, val imageSize: Size) {
    companion object { val Empty = DisplayPose(emptyMap(), Size.Zero) }
}

/** Maps normalized buffer points into an aspect-fill view. */
object PoseMapper {
    fun map(point: Offset, imageSize: Size, viewSize: Size): Offset {
        if (imageSize.width <= 0f || imageSize.height <= 0f) return Offset(point.x * viewSize.width, point.y * viewSize.height)
        val scale = maxOf(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        val w = imageSize.width * scale
        val h = imageSize.height * scale
        return Offset((viewSize.width - w) / 2 + point.x * w, (viewSize.height - h) / 2 + point.y * h)
    }
}

enum class RepPhase { Searching, Calibrating, NoArm, Top, Charging, Charged }

data class RepTracking(val phase: RepPhase, val depth: Double, val calibration: Double) {
    companion object { val Initial = RepTracking(RepPhase.Searching, 0.0, 0.0) }
}

data class RepEvent(var repCompleted: Boolean = false, var justCharged: Boolean = false, var power: Double = 0.0)

/**
 * Turns poses into reps (direct port of the iOS RepDetector): neck anchor,
 * 1 s auto-calibration, hysteresis at 55 % / 25 % with a 0.35 s debounce.
 *
 * - Straight-arm check: push-up calibration can only complete when one arm's
 *   chain (shoulder + elbow + wrist) is visible and near-straight, so holding
 *   still at the bottom can never lock in a false "top". Collinearity survives
 *   projection, so a foreshortened but straight arm still passes. Sit-ups skip
 *   the check — lying flat IS their start position.
 * - Readiness ([isReady]): a live flag for the pre-start countdown. Ready =
 *   calibrated, near the top, and visible. Lost only by a clear lowering (past
 *   50 % of the range for 0.3 s) or the full tracking-loss reset — never by
 *   jitter or a brief flicker.
 */
class RepDetector(private val exercise: Exercise = Exercise.PushUps) {
    companion object {
        const val DOWN_THRESHOLD = 0.55
        const val UP_THRESHOLD = 0.25
        const val DEBOUNCE = 0.35
        const val CALIBRATION_DURATION = 1.0
        const val CALIBRATION_TOLERANCE = 0.035
        const val LOST_TIMEOUT = 2.5
        const val STRAIGHT_ARM_ANGLE = 150.0
        const val LOWERED_DEPTH = 0.5
        const val LOWERED_SECONDS = 0.3
    }

    var state = RepTracking.Initial
        private set

    private var filtered: Double? = null
    private var top: Double? = null
    private var range = 0.12
    private var minRange = 0.08
    private var noseToNeck = 0.07
    private var lastSeen = Double.NEGATIVE_INFINITY
    private var calibrationStart: Double? = null
    private var calibrationMin = 0.0
    private var calibrationMax = 0.0
    private var calibrationSum = 0.0
    private var calibrationCount = 0
    private var spanSum = 0.0
    private var spanCount = 0
    private var isCharged = false
    private var peak = 0.0
    private var lastRep = Double.NEGATIVE_INFINITY

    private var isLowered = false
    private var lowerStart: Double? = null

    /** Live readiness for the pre-start countdown: calibrated, near the top, body visible. */
    var isReady: Boolean = false
        private set

    /** Keeps the calibration but forgets any charge and pending setup movement. Called at GO. */
    fun clearCharge() {
        isCharged = false
        peak = 0.0
    }

    fun reset() {
        filtered = null; top = null; range = 0.12; minRange = 0.08; noseToNeck = 0.07
        lastSeen = Double.NEGATIVE_INFINITY
        calibrationStart = null; calibrationMin = 0.0; calibrationMax = 0.0
        calibrationSum = 0.0; calibrationCount = 0; spanSum = 0.0; spanCount = 0
        isCharged = false; peak = 0.0; lastRep = Double.NEGATIVE_INFINITY
        isLowered = false; lowerStart = null; isReady = false
        state = RepTracking.Initial
    }

    private val direction: Double get() = if (exercise == Exercise.SitUps) -1.0 else 1.0

    fun process(frame: PoseFrame, now: Double): RepEvent {
        val event = RepEvent()
        val raw = anchor(frame)
        if (raw == null) {
            if (now - lastSeen > LOST_TIMEOUT) {
                reset()
            }
            return event
        }
        lastSeen = now
        val y = filtered?.let { it + (raw - it) * 0.45 } ?: raw
        filtered = y

        val currentTop = top
        if (currentTop == null) {
            calibrate(y, frame, now)
            return event
        }

        val delta = y - currentTop
        var depth = direction * delta / range
        if (!isCharged) {
            if (delta * direction < 0) top = currentTop + delta * 0.25
            else if (depth < 0.2) top = currentTop + delta * 0.02
        }
        depth = maxOf(0.0, depth)

        if (!isCharged) {
            if (depth >= DOWN_THRESHOLD) {
                isCharged = true
                peak = depth
                event.justCharged = true
            }
        } else {
            peak = maxOf(peak, depth)
            if (depth <= UP_THRESHOLD) {
                isCharged = false
                if (now - lastRep >= DEBOUNCE) {
                    lastRep = now
                    event.repCompleted = true
                    event.power = ((peak - DOWN_THRESHOLD) / (1 - DOWN_THRESHOLD)).coerceIn(0.0, 1.0)
                    learn(peak)
                }
            }
        }
        updateReadiness(depth, now)
        val phase = if (isCharged) RepPhase.Charged else if (depth > 0.08) RepPhase.Charging else RepPhase.Top
        state = RepTracking(phase, minOf(depth, 1.0), 1.0)
        return event
    }

    private fun updateReadiness(depth: Double, now: Double) {
        if (depth >= LOWERED_DEPTH) {
            if (lowerStart == null) lowerStart = now
            if (now - lowerStart!! >= LOWERED_SECONDS) isLowered = true
        } else {
            lowerStart = null
            if (depth <= UP_THRESHOLD) isLowered = false
        }
        isReady = top != null && !isLowered
    }

    private fun calibrate(y: Double, frame: PoseFrame, now: Double) {
        val isStill = calibrationStart != null && maxOf(calibrationMax, y) - minOf(calibrationMin, y) <= CALIBRATION_TOLERANCE
        if (!isStill) {
            calibrationStart = now
            calibrationMin = y; calibrationMax = y
            calibrationSum = 0.0; calibrationCount = 0
            spanSum = 0.0; spanCount = 0
        }
        calibrationMin = minOf(calibrationMin, y)
        calibrationMax = maxOf(calibrationMax, y)
        calibrationSum += y
        calibrationCount++
        shoulderSpan(frame)?.let { spanSum += it; spanCount++ }

        val progress = minOf((now - (calibrationStart ?: now)) / CALIBRATION_DURATION, 1.0)
        if (progress >= 1 && calibrationCount > 0) {
            // Push-ups may never calibrate on stillness alone: the start
            // position must be verified straight-armed via one visible arm.
            if (exercise == Exercise.PushUps && !hasStraightArm(frame)) {
                state = RepTracking(RepPhase.NoArm, 0.0, progress)
                return
            }
            top = calibrationSum / calibrationCount
            val span = if (spanCount > 0) spanSum / spanCount else 0.2
            val factor = if (exercise == Exercise.SitUps) 0.85 else 0.55
            val lo = if (exercise == Exercise.SitUps) 0.10 else 0.06
            val hi = if (exercise == Exercise.SitUps) 0.30 else 0.22
            range = (span * factor).coerceIn(lo, hi)
            minRange = range * 0.8
            isCharged = false
            isLowered = false
            lowerStart = null
            isReady = true
            calibrationStart = null
            state = RepTracking(RepPhase.Top, 0.0, 1.0)
        } else {
            val armsOK = exercise == Exercise.SitUps || hasStraightArm(frame)
            state = RepTracking(if (armsOK) RepPhase.Calibrating else RepPhase.NoArm, 0.0, progress)
        }
    }

    /** True when either arm's shoulder-elbow-wrist chain is visible and near straight. */
    private fun hasStraightArm(frame: PoseFrame): Boolean {
        if (frame.imageSize.height <= 0f) return false
        val aspect = (frame.imageSize.width / frame.imageSize.height).toDouble()
        val j = frame.joints
        listOf(
            Triple(Joint.LeftShoulder, Joint.LeftElbow, Joint.LeftWrist),
            Triple(Joint.RightShoulder, Joint.RightElbow, Joint.RightWrist)
        ).forEach { (s, e, w) ->
            val shoulder = j[s] ?: return@forEach
            val elbow = j[e] ?: return@forEach
            val wrist = j[w] ?: return@forEach
            if (elbowAngle(shoulder, elbow, wrist, aspect) >= STRAIGHT_ARM_ANGLE) return true
        }
        return false
    }

    /** Interior elbow angle in degrees; x is rescaled by the image aspect for true angles. */
    private fun elbowAngle(shoulder: Offset, elbow: Offset, wrist: Offset, aspect: Double): Double {
        val ux = (shoulder.x - elbow.x) * aspect; val uy = (shoulder.y - elbow.y).toDouble()
        val vx = (wrist.x - elbow.x) * aspect; val vy = (wrist.y - elbow.y).toDouble()
        val dot = ux * vx + uy * vy
        val magnitude = kotlin.math.sqrt(ux * ux + uy * uy) * kotlin.math.sqrt(vx * vx + vy * vy)
        if (magnitude <= 1e-6) return 0.0
        return Math.toDegrees(kotlin.math.acos((dot / magnitude).coerceIn(-1.0, 1.0)))
    }

    private fun learn(peak: Double) {
        val blended = range * 0.75 + peak * range * 0.25
        val ceiling = if (exercise == Exercise.SitUps) 0.38 else 0.3
        range = blended.coerceIn(minRange, ceiling)
    }

    private fun anchor(frame: PoseFrame): Double? {
        val j = frame.joints
        val neck = j[Joint.Neck]
        val nose = j[Joint.Nose]
        if (neck != null && nose != null) noseToNeck += ((neck.y - nose.y) - noseToNeck) * 0.05
        if (neck != null) return neck.y.toDouble()
        val l = j[Joint.LeftShoulder]
        val r = j[Joint.RightShoulder]
        if (l != null && r != null) return ((l.y + r.y) / 2).toDouble()
        (l ?: r)?.let { return it.y.toDouble() }
        if (nose != null) return nose.y + noseToNeck
        return null
    }

    private fun shoulderSpan(frame: PoseFrame): Double? {
        val l = frame.joints[Joint.LeftShoulder] ?: return null
        val r = frame.joints[Joint.RightShoulder] ?: return null
        if (frame.imageSize.height <= 0f) return null
        return abs(l.x - r.x).toDouble() * frame.imageSize.width / frame.imageSize.height
    }
}

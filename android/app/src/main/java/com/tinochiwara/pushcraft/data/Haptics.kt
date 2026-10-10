package com.tinochiwara.pushcraft.data

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Vibration patterns mirroring the iOS HapticService. */
object Haptics {
    private var vibrator: Vibrator? = null
    private var lastTapAt = 0L

    fun init(context: Context) {
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    private val enabled: Boolean get() = AppPreferences.hapticsEnabled

    private fun oneShot(ms: Long, amplitude: Int) {
        val v = vibrator ?: return
        if (!enabled || !v.hasVibrator()) return
        val amp = if (v.hasAmplitudeControl()) amplitude.coerceIn(1, 255) else VibrationEffect.DEFAULT_AMPLITUDE
        v.vibrate(VibrationEffect.createOneShot(ms, amp))
    }

    private fun predefined(effect: Int, fallbackMs: Long, fallbackAmp: Int) {
        val v = vibrator ?: return
        if (!enabled || !v.hasVibrator()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            v.vibrate(VibrationEffect.createPredefined(effect))
        } else {
            oneShot(fallbackMs, fallbackAmp)
        }
    }

    private fun claimTap(): Boolean {
        val now = System.currentTimeMillis()
        if (now - lastTapAt < 350) return false
        lastTapAt = now
        return true
    }

    fun tap() { if (claimTap()) predefined(VibrationEffect.EFFECT_CLICK, 12, 110) }
    fun selection() { if (claimTap()) predefined(VibrationEffect.EFFECT_CLICK, 12, 110) }
    fun tick() = predefined(VibrationEffect.EFFECT_TICK, 6, 60)
    fun charged() = oneShot(18, 140)
    fun hit(power: Double) = oneShot(28, (190 + 65 * power).toInt())
    fun smash() = oneShot(70, 255)
    fun coinTick() = oneShot(8, 90)
    fun land() = oneShot(22, 150)
    fun thud() = predefined(VibrationEffect.EFFECT_HEAVY_CLICK, 25, 200)
    fun stoneLand() = oneShot(45, 255)

    fun success() {
        val v = vibrator ?: return
        if (!enabled || !v.hasVibrator()) return
        v.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 18, 70, 28), -1))
    }

    fun warning() {
        val v = vibrator ?: return
        if (!enabled || !v.hasVibrator()) return
        v.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 30, 80, 30), -1))
    }

    fun finale() {
        oneShot(80, 255)
        CoroutineScope(Dispatchers.Main).launch {
            delay(180)
            oneShot(80, 255)
        }
    }
}

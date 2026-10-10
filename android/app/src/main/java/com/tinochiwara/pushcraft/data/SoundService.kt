package com.tinochiwara.pushcraft.data

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import com.tinochiwara.pushcraft.R

/** Low-latency SFX with per-play pitch (SoundPool rate 0.5–2.0). */
object SoundService {
    enum class Effect { Hit, Shatter, Coins, Drop }

    private var pool: SoundPool? = null
    private val ids = mutableMapOf<Effect, Int>()

    fun init(context: Context) {
        if (pool != null) return
        val sp = SoundPool.Builder()
            .setMaxStreams(8)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            .build()
        ids[Effect.Hit] = sp.load(context, R.raw.punch_impact_crack, 1)
        ids[Effect.Shatter] = sp.load(context, R.raw.block_shatter_explosion, 1)
        ids[Effect.Coins] = sp.load(context, R.raw.arcade_coin_payout, 1)
        ids[Effect.Drop] = sp.load(context, R.raw.block_drop_thud, 1)
        pool = sp
    }

    fun play(effect: Effect, pitch: Float = 1f, volume: Float = 1f) {
        if (!AppPreferences.soundEnabled) return
        val id = ids[effect] ?: return
        val v = volume.coerceIn(0f, 1f)
        pool?.play(id, v, v, 1, 0, pitch.coerceIn(0.5f, 2f))
    }
}

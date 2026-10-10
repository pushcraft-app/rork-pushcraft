package com.tinochiwara.pushcraft.ui.components

import android.content.Context
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.tinochiwara.pushcraft.R
import com.tinochiwara.pushcraft.data.Backend
import com.tinochiwara.pushcraft.ui.theme.Pc
import kotlinx.serialization.Serializable

/** Cut-out stage parts and traced outlines for one tower (from tower_parts.json). */
@Serializable
data class TowerPartsEntry(
    val silhouette: List<List<List<Double>>>,
    val parts: Map<String, List<List<List<Double>>>>,
    val rects: Map<String, List<Double>>
)

object TowerParts {
    const val STAGE_COUNT = 9
    private var library: Map<String, TowerPartsEntry>? = null

    fun load(context: Context): Map<String, TowerPartsEntry> {
        library?.let { return it }
        val parsed = runCatching {
            val text = context.assets.open("tower_parts.json").bufferedReader().use { it.readText() }
            Backend.json.decodeFromString<Map<String, TowerPartsEntry>>(text)
        }.getOrDefault(emptyMap())
        library = parsed
        return parsed
    }

    fun rect(entry: TowerPartsEntry, stage: Int): Rect? {
        val r = entry.rects[stage.toString()] ?: return null
        if (r.size != 4) return null
        return Rect(r[0].toFloat(), r[1].toFloat(), (r[0] + r[2]).toFloat(), (r[1] + r[3]).toFloat())
    }

    private val parts = mapOf(
        "oakspire" to listOf(R.drawable.tower_oakspire_part1, R.drawable.tower_oakspire_part2, R.drawable.tower_oakspire_part3, R.drawable.tower_oakspire_part4, R.drawable.tower_oakspire_part5, R.drawable.tower_oakspire_part6, R.drawable.tower_oakspire_part7, R.drawable.tower_oakspire_part8, R.drawable.tower_oakspire_part9),
        "stonewatch" to listOf(R.drawable.tower_stonewatch_part1, R.drawable.tower_stonewatch_part2, R.drawable.tower_stonewatch_part3, R.drawable.tower_stonewatch_part4, R.drawable.tower_stonewatch_part5, R.drawable.tower_stonewatch_part6, R.drawable.tower_stonewatch_part7, R.drawable.tower_stonewatch_part8, R.drawable.tower_stonewatch_part9),
        "frostkeep" to listOf(R.drawable.tower_frostkeep_part1, R.drawable.tower_frostkeep_part2, R.drawable.tower_frostkeep_part3, R.drawable.tower_frostkeep_part4, R.drawable.tower_frostkeep_part5, R.drawable.tower_frostkeep_part6, R.drawable.tower_frostkeep_part7, R.drawable.tower_frostkeep_part8, R.drawable.tower_frostkeep_part9),
        "emberhold" to listOf(R.drawable.tower_emberhold_part1, R.drawable.tower_emberhold_part2, R.drawable.tower_emberhold_part3, R.drawable.tower_emberhold_part4, R.drawable.tower_emberhold_part5, R.drawable.tower_emberhold_part6, R.drawable.tower_emberhold_part7, R.drawable.tower_emberhold_part8, R.drawable.tower_emberhold_part9),
        "skyward_spire" to listOf(R.drawable.tower_skyward_spire_part1, R.drawable.tower_skyward_spire_part2, R.drawable.tower_skyward_spire_part3, R.drawable.tower_skyward_spire_part4, R.drawable.tower_skyward_spire_part5, R.drawable.tower_skyward_spire_part6, R.drawable.tower_skyward_spire_part7, R.drawable.tower_skyward_spire_part8, R.drawable.tower_skyward_spire_part9)
    )

    fun partRes(key: String, stage: Int): Int? = parts[key]?.getOrNull(stage - 1)

    fun cardRes(key: String?): Int = when (key) {
        "stonewatch" -> R.drawable.card_stonewatch
        "frostkeep" -> R.drawable.card_frostkeep
        "emberhold" -> R.drawable.card_emberhold
        "skyward_spire" -> R.drawable.card_skyward_spire
        else -> R.drawable.card_oakspire
    }
}

/** Resolves a tower id or display name ("Skyward Spire") to its art key. */
object TowerArt {
    private val keys = setOf("oakspire", "stonewatch", "frostkeep", "emberhold", "skyward_spire")
    fun key(raw: String?): String? {
        raw ?: return null
        val n = raw.lowercase().replace(Regex("[^a-z0-9]+"), "_").trim('_')
        return n.takeIf { it in keys }
    }
}

/** One cut-out stage part, placed exactly where it sits in the full tower. */
@Composable
fun TowerPartLayer(key: String, stage: Int, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val entry = TowerParts.load(context)[key] ?: return
    val r = TowerParts.rect(entry, stage) ?: return
    val res = TowerParts.partRes(key, stage) ?: return
    BoxWithConstraints(modifier.fillMaxSize()) {
        Image(
            painterResource(res), null,
            contentScale = ContentScale.FillBounds,
            modifier = Modifier
                .offset(maxWidth * r.left, maxHeight * r.top)
                .size(maxWidth * r.width, maxHeight * r.height)
        )
    }
}

private fun contoursPath(contours: List<List<List<Double>>>, w: Float, h: Float): Path = Path().apply {
    for (c in contours) {
        val first = c.firstOrNull() ?: continue
        if (first.size != 2) continue
        moveTo(first[0].toFloat() * w, first[1].toFloat() * h)
        for (p in c.drop(1)) if (p.size == 2) lineTo(p[0].toFloat() * w, p[1].toFloat() * h)
        close()
    }
}

/** Dashed ivory outline with a faint cyan glow (whole tower or one part). */
@Composable
fun TowerOutlineLayer(key: String, stage: Int?, intensity: Float = 1f, modifier: Modifier = Modifier) {
    val entry = TowerParts.load(LocalContext.current)[key] ?: return
    val contours = if (stage == null) entry.silhouette else entry.parts[stage.toString()].orEmpty()
    Canvas(modifier.fillMaxSize()) {
        val path = contoursPath(contours, size.width, size.height)
        drawPath(path, Pc.progressCyan.copy(alpha = 0.35f * intensity), style = Stroke(4.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
        drawPath(
            path, Pc.ivory.copy(alpha = 0.85f * intensity),
            style = Stroke(1.3.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round, pathEffect = PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 4.dp.toPx())))
        )
    }
}

/** Faint filled silhouette of the finished tower behind built parts. */
@Composable
fun TowerSilhouetteLayer(key: String, modifier: Modifier = Modifier) {
    val entry = TowerParts.load(LocalContext.current)[key] ?: return
    Canvas(modifier.fillMaxSize()) {
        val path = contoursPath(entry.silhouette, size.width, size.height)
        drawPath(path, Color(0xFF081120).copy(alpha = 0.55f))
        drawPath(path, Pc.ivory.copy(alpha = 0.25f), style = Stroke(1.dp.toPx()))
    }
}

/**
 * A tower assembled from its nine stage parts: built stages in full color, the
 * current stage fading in with progress under its dashed outline; locked or
 * unstarted towers show the whole dashed silhouette.
 */
@Composable
fun TowerConstructionView(
    towerId: String?,
    builtStages: Int,
    stageFraction: Double = 0.0,
    isLocked: Boolean = false,
    modifier: Modifier = Modifier
) {
    val key = TowerArt.key(towerId)
    val built = builtStages.coerceIn(0, TowerParts.STAGE_COUNT)
    val fraction by animateFloatAsState(stageFraction.toFloat().coerceIn(0f, 1f), tween(600), label = "fraction")
    val unstarted = isLocked || (built == 0 && stageFraction <= 0.001)
    val current = if (built < TowerParts.STAGE_COUNT) built + 1 else null
    Box(modifier.aspectRatio(2f / 3f), contentAlignment = Alignment.Center) {
        if (key != null && TowerParts.load(LocalContext.current)[key] != null) {
            if (unstarted) {
                TowerOutlineLayer(key, null, if (isLocked) 0.45f else 1f)
            } else {
                if (current != null) TowerSilhouetteLayer(key)
                for (i in 1..built) TowerPartLayer(key, i)
                if (current != null) {
                    TowerPartLayer(key, current, Modifier.alpha(fraction))
                    TowerOutlineLayer(key, current, 1f - 0.45f * fraction)
                }
            }
        } else {
            Image(
                painterResource(R.drawable.watchtower_construction), null,
                modifier = Modifier.fillMaxSize().alpha(if (unstarted) 0.25f else 1f),
                contentScale = ContentScale.Fit
            )
        }
    }
}

@Suppress("unused")
private val zero = Offset.Zero

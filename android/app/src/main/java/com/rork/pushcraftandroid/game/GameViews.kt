package com.rork.pushcraftandroid.game

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotateRad
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.imageResource
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.rork.pushcraftandroid.R
import com.rork.pushcraftandroid.model.Exercise
import com.rork.pushcraftandroid.ui.theme.Pc
import com.rork.pushcraftandroid.ui.theme.rounded
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin

private val bones = listOf(
    Joint.LeftShoulder to Joint.RightShoulder, Joint.Neck to Joint.Nose, Joint.Neck to Joint.Root,
    Joint.LeftShoulder to Joint.LeftElbow, Joint.LeftElbow to Joint.LeftWrist,
    Joint.RightShoulder to Joint.RightElbow, Joint.RightElbow to Joint.RightWrist,
    Joint.LeftShoulder to Joint.LeftHip, Joint.RightShoulder to Joint.RightHip, Joint.LeftHip to Joint.RightHip,
    Joint.LeftHip to Joint.LeftKnee, Joint.LeftKnee to Joint.LeftAnkle,
    Joint.RightHip to Joint.RightKnee, Joint.RightKnee to Joint.RightAnkle
)

/** Crisp white stick figure over the camera feed. */
@Composable
fun SkeletonView(pose: DisplayPose, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        if (pose.joints.isEmpty()) return@Canvas
        fun pt(j: Joint) = pose.joints[j]?.let { PoseMapper.map(it, pose.imageSize, size) }
        for ((a, b) in bones) {
            val pa = pt(a) ?: continue
            val pb = pt(b) ?: continue
            drawLine(Color.Black.copy(alpha = 0.3f), pa, pb, 5.dp.toPx(), StrokeCap.Round)
            drawLine(Color.White, pa, pb, 2.5.dp.toPx(), StrokeCap.Round)
        }
        for (joint in pose.joints.keys) {
            val p = pt(joint) ?: continue
            val r = (if (joint.isFace) 3f else 5.5f).dp.toPx()
            drawCircle(Color.Black.copy(alpha = 0.3f), r + 1.5.dp.toPx(), p)
            drawCircle(Color.White, r, p)
        }
    }
}

/** The floating block: texture, neon rim, cracks, charge glow and hit punch. */
@Composable
fun BlockView(
    tier: BlockTier,
    seed: Long,
    damage: Double,
    charge: Double,
    isCharged: Boolean,
    hitTrigger: Int,
    modifier: Modifier = Modifier,
    side: Float = 150f
) {
    val glow = if (isCharged) Pc.gold else tier.accent
    val crackCount = if (damage <= 0) 0 else Math.ceil(damage * 8).toInt() + 1
    val cracks = remember(seed, crackCount) { CrackGenerator.make(seed, crackCount) }
    val animCharge by animateFloatAsState(charge.toFloat(), tween(150), label = "charge")

    val shakeX = remember { Animatable(0f) }
    val shakeY = remember { Animatable(0f) }
    val punch = remember { Animatable(1f) }
    val flash = remember { Animatable(0f) }
    val rot = remember { Animatable(0f) }
    LaunchedEffect(hitTrigger) {
        if (hitTrigger == 0) return@LaunchedEffect
        flash.snapTo(0.95f)
        kotlinx.coroutines.coroutineScope {
            launch { flash.animateTo(0f, tween(240)) }
            launch {
                shakeY.animateTo(-30f, tween(70))
                shakeY.animateTo(6f, tween(140))
                shakeY.animateTo(0f, spring(dampingRatio = 0.45f, stiffness = Spring.StiffnessMedium))
            }
            launch {
                for (x in listOf(-12f, 11f, -8f, 5f, -2f, 0f)) shakeX.animateTo(x, tween(55, easing = LinearEasing))
            }
            launch {
                for (r in listOf(-5f, 4f, -2f)) rot.animateTo(r, tween(65))
                rot.animateTo(0f, spring())
            }
            launch {
                punch.animateTo(1.14f, tween(70))
                punch.animateTo(0.95f, tween(120))
                punch.animateTo(1f, spring(dampingRatio = 0.45f, stiffness = Spring.StiffnessMedium))
            }
        }
    }

    val shape = RoundedCornerShape((side * 0.13f).dp)
    Box(
        modifier
            .size(side.dp)
            .offset { IntOffset(shakeX.value.dp.roundToPx(), shakeY.value.dp.roundToPx()) }
            .graphicsLayer {
                scaleX = punch.value; scaleY = punch.value; rotationZ = rot.value
            },
        contentAlignment = Alignment.Center
    ) {
        // charge glow
        Box(
            Modifier
                .size(side.dp)
                .scale(1f + 0.12f * animCharge)
                .blur((14 + 18 * animCharge).dp)
                .background(glow.copy(alpha = 0.25f + 0.55f * animCharge), shape)
        )
        Box(Modifier.size(side.dp).clip(shape)) {
            Image(painterResource(tier.texture), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
            Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = (damage * 0.2).toFloat())))
            Canvas(Modifier.fillMaxSize()) {
                for (c in cracks) {
                    val path = Path()
                    c.points.forEachIndexed { i, p ->
                        val o = Offset(p.x * size.width, p.y * size.height)
                        if (i == 0) path.moveTo(o.x, o.y) else path.lineTo(o.x, o.y)
                    }
                    translate(1.2f, 1.4f) {
                        drawPath(path, Color.White.copy(alpha = 0.35f), style = Stroke(c.width * 0.5f * density / 2, cap = StrokeCap.Round))
                    }
                    drawPath(path, Color(0xE60B0F14), style = Stroke(c.width * density / 2, cap = StrokeCap.Round, join = StrokeJoin.Miter))
                }
            }
            Text(
                "!",
                style = rounded((side * 0.42f).toInt(), FontWeight.Black),
                color = Color.White.copy(alpha = 0.92f),
                modifier = Modifier.align(Alignment.Center)
            )
            Box(
                Modifier.fillMaxSize().border(
                    6.dp,
                    Brush.verticalGradient(listOf(Color.White.copy(alpha = 0.4f), Color.Transparent, Color.Black.copy(alpha = 0.45f))),
                    shape
                )
            )
            Box(Modifier.fillMaxSize().background(Color.White.copy(alpha = flash.value)))
        }
        Box(Modifier.size(side.dp).shadow(6.dp, shape, ambientColor = glow, spotColor = glow).border(3.dp, glow, shape))
        Box(Modifier.size(side.dp).padding(3.dp).border(1.dp, Color.White.copy(alpha = 0.7f), shape))
    }
}

/** Full-screen particle layer: beams, rings, shards and coin bursts (root coords). */
@Composable
fun EffectsOverlay(engine: GameEngine, modifier: Modifier = Modifier) {
    var nowMs by remember { mutableLongStateOf(android.os.SystemClock.uptimeMillis()) }
    val active = engine.hasActiveEffects
    LaunchedEffect(active) {
        while (active) {
            withFrameMillis { }
            nowMs = android.os.SystemClock.uptimeMillis()
        }
    }
    val coinImage = androidx.compose.ui.graphics.ImageBitmap.imageResource(R.drawable.gold_coin_star)
    Canvas(modifier) {
        val now = nowMs
        for (beam in engine.beams) {
            val t = (now - beam.start) / 1000.0 / HitBeam.LIFETIME
            if (t < 0 || t >= 1) continue
            val fade = (1 - t).toFloat()
            drawLine(beam.color.copy(alpha = 0.5f * fade), beam.from, beam.to, 18f * fade * density / 2, StrokeCap.Round)
            drawLine(Color.White.copy(alpha = fade), beam.from, beam.to, 5f * fade * density / 2, StrokeCap.Round)
        }
        for (ring in engine.rings) {
            val t = (now - ring.start) / 1000.0 / ShockRing.LIFETIME
            if (t < 0 || t >= 1) continue
            val eased = 1 - (1 - t).pow(3)
            val maxR = if (ring.isBig) 260.0 else 90 + 70 * ring.power
            val r = ((24 + (maxR - 24) * eased) * density / 2.5).toFloat()
            val squash = if (ring.isBig) 1f else 0.42f
            val fade = (1 - t).toFloat()
            val tl = Offset(ring.origin.x - r, ring.origin.y - r * squash)
            val sz = Size(r * 2, r * 2 * squash)
            drawOval(ring.color.copy(alpha = fade * 0.7f), tl, sz, style = Stroke(12f * fade))
            drawOval(Color.White.copy(alpha = 0.9f * fade), tl, sz, style = Stroke(3.5f * fade + 0.5f))
        }
        for (burst in engine.shardBursts) {
            val t = (now - burst.start) / 1000.0
            if (t < 0 || t >= ShardBurst.LIFETIME) continue
            val fade = (1 - (t / ShardBurst.LIFETIME).pow(2)).toFloat()
            val k = density / 2.5f
            for (s in burst.shards) {
                val x = (burst.origin.x + s.vx * t * k).toFloat()
                val y = (burst.origin.y + (s.vy * t + 0.5 * 1500 * t * t) * k).toFloat()
                translate(x, y) {
                    rotateRad((s.rotation + s.spin * t).toFloat(), Offset.Zero) {
                        val path = Path()
                        val radius = (s.size / 2 * density / 2).toFloat()
                        for (i in 0 until s.sides) {
                            val a = i.toDouble() / s.sides * 2 * Math.PI
                            val rr = radius * if (i % 2 == 0) 1f else 0.7f
                            val px = (cos(a) * rr).toFloat(); val py = (sin(a) * rr).toFloat()
                            if (i == 0) path.moveTo(px, py) else path.lineTo(px, py)
                        }
                        path.close()
                        drawPath(path, burst.color.copy(alpha = fade))
                        drawPath(path, Color.Black.copy(alpha = (s.shade * fade).toFloat()))
                        drawPath(path, Color.White.copy(alpha = 0.35f * fade), style = Stroke(1f))
                    }
                }
            }
        }
        for (burst in engine.coinBursts) {
            val t = (now - burst.start) / 1000.0
            for (coin in burst.coins) {
                val (pt, sz0) = burst.state(coin, t) ?: continue
                val spin = maxOf(abs(cos(coin.spin * t)).toFloat(), 0.18f)
                val s = sz0 * density / 2.2f
                translate(pt.x, pt.y) {
                    scale(spin, 1f, Offset.Zero) {
                        drawCircle(Pc.gold.copy(alpha = 0.35f), s * 0.6f, Offset.Zero)
                        drawImage(
                            coinImage,
                            dstOffset = IntOffset((-s / 2).roundToInt(), (-s / 2).roundToInt()),
                            dstSize = IntSize(s.roundToInt(), s.roundToInt())
                        )
                    }
                }
            }
        }
    }
}

/** Charge bar: fills on the way down, turns gold once the rep is charged. */
@Composable
fun DepthMeter(tracking: RepTracking, modifier: Modifier = Modifier) {
    val calibrating = tracking.phase == RepPhase.Calibrating
    val charged = tracking.phase == RepPhase.Charged
    val fill = (if (calibrating) tracking.calibration else tracking.depth).toFloat()
    val color = if (calibrating) Color.White else if (charged) Pc.gold else Pc.cyan
    val animFill by animateFloatAsState(fill, spring(dampingRatio = 0.85f, stiffness = 900f), label = "fill")
    val scale by animateFloatAsState(if (charged) 1.03f else 1f, spring(dampingRatio = 0.55f), label = "scale")
    Box(
        modifier
            .scale(scale)
            .shadow(8.dp, CircleShape, ambientColor = color, spotColor = color)
            .background(Color.Black.copy(alpha = 0.5f), CircleShape)
            .border(2.dp, color.copy(alpha = 0.95f), CircleShape)
            .padding(5.dp)
            .height(20.dp)
            .fillMaxWidth()
    ) {
        BoxWithConstraints(Modifier.fillMaxSize().clip(CircleShape).background(Pc.track)) {
            val w = maxWidth
            if (animFill > 0.01f) {
                Box(
                    Modifier
                        .fillMaxHeight()
                        .width(maxOf(w * animFill, 20.dp))
                        .background(Brush.horizontalGradient(listOf(color.copy(alpha = 0.7f), color, Color.White.copy(alpha = 0.9f))), CircleShape)
                )
            }
            if (!calibrating) {
                Box(
                    Modifier
                        .offset(x = w * RepDetector.DOWN_THRESHOLD.toFloat() - 1.5.dp)
                        .align(Alignment.CenterStart)
                        .width(3.dp)
                        .fillMaxHeight(0.7f)
                        .background(Color.White.copy(alpha = if (charged) 0f else 0.5f), CircleShape)
                )
            }
        }
    }
}

/** Helper text under the depth meter. Chevrons only for charge/smash cues. */
@Composable
fun CueView(cue: CoachCue, exercise: Exercise, modifier: Modifier = Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (cue.showsChevrons) {
            val down = cue == CoachCue.GoDown && exercise == Exercise.PushUps
            val color = if (cue == CoachCue.GoDown) Pc.cyan else Pc.gold
            val inf = rememberInfiniteTransition(label = "chev")
            val phase by inf.animateFloat(0f, 1f, infiniteRepeatable(tween(500, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "p")
            val dir = if (down) 1f else -1f
            Column(
                Modifier.height(26.dp).offset(y = ((-3 + 8 * phase) * dir).dp).alpha(0.55f + 0.45f * phase),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy((-14).dp)
            ) {
                repeat(2) {
                    Icon(if (down) Icons.Filled.KeyboardArrowDown else Icons.Filled.KeyboardArrowUp, null, tint = color, modifier = Modifier.size(24.dp))
                }
            }
        }
        AnimatedContent(cue, transitionSpec = { (scaleIn(initialScale = 0.85f) + fadeIn()) togetherWith fadeOut() }, label = "cue") { c ->
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Row(
                    Modifier
                        .shadow(6.dp, CircleShape, ambientColor = c.tint, spotColor = c.tint)
                        .background(Pc.panel, CircleShape)
                        .border(2.dp, c.tint, CircleShape)
                        .padding(horizontal = 20.dp, vertical = 11.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    c.icon?.let { Icon(it, null, tint = Color.White, modifier = Modifier.size(16.dp)) }
                    Text(c.title(exercise), style = rounded(15, FontWeight.ExtraBold, 1.4f), color = Color.White)
                }
                c.subtitle(exercise)?.let {
                    Text(
                        it, style = rounded(12, FontWeight.SemiBold), color = Color.White.copy(alpha = 0.85f),
                        textAlign = TextAlign.Center, modifier = Modifier.padding(top = 4.dp, start = 24.dp, end = 24.dp)
                    )
                }
            }
        }
    }
}

/** Gold health pips — filled = remaining hits. */
@Composable
fun HealthPips(total: Int, remaining: Int, modifier: Modifier = Modifier) {
    val size = when {
        total <= 5 -> 20
        total <= 7 -> 17
        else -> 14
    }
    Row(modifier, horizontalArrangement = Arrangement.spacedBy((size * 0.34f).dp)) {
        for (i in 0 until total) {
            val filled = i < remaining
            val s by animateFloatAsState(if (filled) 1f else 0.2f, spring(dampingRatio = 0.5f), label = "pip")
            Box(Modifier.size(size.dp).scale(if (filled) 1f else 0.86f), contentAlignment = Alignment.Center) {
                Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.45f), CircleShape).border(2.dp, Color.White.copy(alpha = 0.45f), CircleShape))
                Box(
                    Modifier
                        .fillMaxSize()
                        .scale(s)
                        .alpha(if (filled) 1f else 0f)
                        .background(Brush.radialGradient(listOf(Color(0xFFFFE680), Pc.gold, Color(0xFFE08A00))), CircleShape)
                        .border(1.5.dp, Color(0xFF9A5A00), CircleShape)
                )
            }
        }
    }
}

/** Top-corner counter that bumps whenever its value changes. */
@Composable
fun StatCard(value: Int, label: String, tint: Color, modifier: Modifier = Modifier, icon: @Composable () -> Unit) {
    val bump = remember { Animatable(1f) }
    LaunchedEffect(value) {
        if (value == 0) return@LaunchedEffect
        bump.animateTo(1.14f, tween(80))
        bump.animateTo(1f, spring(dampingRatio = 0.45f))
    }
    val shape = RoundedCornerShape(18.dp)
    Row(
        modifier
            .scale(bump.value)
            .widthIn(min = 94.dp)
            .shadow(6.dp, shape, ambientColor = tint, spotColor = tint)
            .background(Pc.panel, shape)
            .border(2.dp, tint, shape)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        icon()
        Column {
            Text("$value", style = rounded(27, FontWeight.ExtraBold), color = Color.White)
            Text(label, style = rounded(10, FontWeight.Bold, 2.2f), color = Color.White.copy(alpha = 0.85f))
        }
    }
}

/** "+N" coin payout popup over the block. */
@Composable
fun PayoutText(amount: Int, modifier: Modifier = Modifier) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Image(painterResource(R.drawable.gold_coin_star), null, Modifier.size(34.dp))
        Text(
            "+$amount",
            style = rounded(46, FontWeight.Black).copy(
                brush = Brush.verticalGradient(listOf(Color.White, Pc.gold)),
                shadow = androidx.compose.ui.graphics.Shadow(Pc.gold.copy(alpha = 0.9f), Offset.Zero, 24f)
            )
        )
    }
}

@Suppress("unused")
private fun Rect.safe() = this

@Composable
internal fun Spacer12() = Spacer(Modifier.height(12.dp))

@Suppress("unused")
private val keepRotate = Modifier.rotate(0f)

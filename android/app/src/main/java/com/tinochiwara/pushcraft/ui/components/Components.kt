package com.tinochiwara.pushcraft.ui.components

import android.graphics.BitmapFactory
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.tinochiwara.pushcraft.R
import com.tinochiwara.pushcraft.data.Backend
import com.tinochiwara.pushcraft.data.Haptics
import com.tinochiwara.pushcraft.ui.theme.Pc
import com.tinochiwara.pushcraft.ui.theme.rounded
import com.tinochiwara.pushcraft.ui.theme.serif
import io.github.jan.supabase.storage.storage

/** Springy press-down with a light haptic on touch, no ripple. */
fun Modifier.pressScale(enabled: Boolean = true, onClick: () -> Unit): Modifier = this.then(
    Modifier.composedPress(enabled, onClick)
)

@Composable
private fun pressState(): Pair<MutableInteractionSource, Float> {
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    LaunchedEffect(pressed) { if (pressed) Haptics.tap() }
    val scale by animateFloatAsState(if (pressed) 0.97f else 1f, spring(dampingRatio = 0.7f, stiffness = 900f), label = "press")
    return source to scale
}

@Suppress("ModifierFactoryUnreferencedReceiver")
private fun Modifier.composedPress(enabled: Boolean, onClick: () -> Unit): Modifier = this.composed {
    val (source, scale) = pressState()
    this
        .graphicsLayer { scaleX = scale; scaleY = scale }
        .clickable(interactionSource = source, indication = null, enabled = enabled, onClick = onClick)
}

/** Navy battle-card surface with a subtle blue border. */
fun Modifier.battleCard(radius: Dp = 22.dp): Modifier =
    this.background(Pc.battleCard, RoundedCornerShape(radius)).border(1.dp, Pc.battleCardBorder, RoundedCornerShape(radius))

/** Recessed darker inset for fields and the code row. */
fun Modifier.recessed(): Modifier =
    this.background(Color.Black.copy(alpha = 0.28f), RoundedCornerShape(14.dp)).border(1.dp, Color.White.copy(alpha = 0.08f), RoundedCornerShape(14.dp))

val AmberGradient = Brush.verticalGradient(listOf(Pc.amberSoft, Pc.amberDeep))

/** Full-width gold-to-orange button with dark text. */
@Composable
fun GoldButton(
    title: String,
    modifier: Modifier = Modifier,
    isLoading: Boolean = false,
    enabled: Boolean = true,
    height: Dp = 54.dp,
    radius: Dp = 16.dp,
    textSize: Int = 19,
    icon: (@Composable () -> Unit)? = null,
    onClick: () -> Unit
) {
    val shape = RoundedCornerShape(radius)
    Row(
        modifier
            .fillMaxWidth()
            .alpha(if (enabled) 1f else 0.5f)
            .height(height)
            .shadow(12.dp, shape, ambientColor = Pc.amberDeep, spotColor = Pc.amberDeep)
            .background(AmberGradient, shape)
            .pressScale(enabled && !isLoading, onClick),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (isLoading) {
            CircularProgressIndicator(Modifier.size(20.dp), color = Pc.buttonInk, strokeWidth = 2.5.dp)
        } else {
            icon?.invoke()
        }
        if (isLoading || icon != null) Spacer(Modifier.width(10.dp))
        Text(title, style = rounded(textSize, FontWeight.Bold), color = Pc.buttonInk)
    }
}

/** Dark translucent capsule counter (streak, XP, coins). */
@Composable
fun StatPill(value: String, valueColor: Color, suffix: String? = null, modifier: Modifier = Modifier, icon: (@Composable () -> Unit)? = null) {
    Row(
        modifier
            .height(32.dp)
            .shadow(8.dp, CircleShape, ambientColor = Color.Black, spotColor = Color.Black)
            .background(Pc.pillFill, CircleShape)
            .border(1.dp, Pc.pillBorder, CircleShape)
            .padding(horizontal = 11.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp)
    ) {
        icon?.invoke()
        Text(value, style = rounded(15, FontWeight.Bold), color = valueColor)
        suffix?.let { Text(it, style = rounded(12, FontWeight.Bold), color = valueColor) }
    }
}

@Composable
fun FlameIcon(size: Dp = 15.dp) {
    Icon(
        Icons.Filled.LocalFireDepartment, null,
        modifier = Modifier
            .size(size)
            .graphicsLayer(alpha = 0.99f)
            .drawWithGradient(Brush.verticalGradient(listOf(Pc.amberSoft, Color(0xFFFF6B1E)))),
        tint = Color.Unspecified
    )
}

private fun Modifier.drawWithGradient(brush: Brush): Modifier = this.then(
    Modifier.drawWithContentCompat(brush)
)

private fun Modifier.drawWithContentCompat(brush: Brush): Modifier = this.drawWithCache {
    onDrawWithContent {
        drawContent()
        drawRect(brush, blendMode = androidx.compose.ui.graphics.BlendMode.SrcAtop)
    }
}

/** Streak / XP / coins row shared by Home, Towers and Battles headers. */
@Composable
fun CountersRow(streak: Int, xp: Int, coins: String, modifier: Modifier = Modifier) {
    var showStore by remember { mutableStateOf(false) }
    Row(modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        StatPill("$streak", Pc.streakOrange) { FlameIcon() }
        StatPill("$xp", Pc.progressCyan, suffix = "XP")
        Spacer(Modifier.weight(1f))
        StatPill(coins, Pc.gold, modifier = Modifier.pressScale { showStore = true }) {
            Image(painterResource(R.drawable.gold_coin_star), null, Modifier.size(18.dp))
        }
    }
    if (showStore) {
        val state = rememberModalBottomSheetState()
        ModalBottomSheet(onDismissRequest = { showStore = false }, sheetState = state, containerColor = Pc.towersNavy) {
            Column(
                Modifier.fillMaxWidth().padding(start = 24.dp, end = 24.dp, bottom = 40.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                Image(painterResource(R.drawable.gold_coin_star), null, Modifier.size(64.dp))
                Text("Store coming soon", style = serif(24), color = Pc.ivory)
                Text(
                    "Spend your coins on boosters and cosmetics once the shop opens. Keep building!",
                    style = rounded(15, FontWeight.Medium), color = Pc.mist, textAlign = TextAlign.Center
                )
            }
        }
    }
}

/** Ivory chevron + "Back" text button. */
@Composable
fun BackTextButton(modifier: Modifier = Modifier, onClick: () -> Unit) {
    Row(modifier.pressScale(onClick = onClick).padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.AutoMirrored.Filled.ArrowBack, null, tint = Pc.ivory, modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(6.dp))
        Text("Back", style = rounded(17, FontWeight.SemiBold), color = Pc.ivory)
    }
}

/** Crossed swords glyph (two drawn swords at ±45°). */
@Composable
fun CrossedSwordsIcon(color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        fun sword(): Path = Path().apply {
            val w = size.width; val h = size.height
            moveTo(0.5f * w, 0f); lineTo(0.565f * w, 0.12f * h); lineTo(0.565f * w, 0.56f * h)
            lineTo(0.435f * w, 0.56f * h); lineTo(0.435f * w, 0.12f * h); close()
            addRect(Rect(0.33f * w, 0.56f * h, 0.67f * w, 0.63f * h))
            addRect(Rect(0.455f * w, 0.63f * h, 0.545f * w, 0.87f * h))
            addOval(Rect(Offset(0.43f * w, 0.87f * h), Size(0.14f * w, 0.14f * h)))
        }
        rotate(45f) { drawPath(sword(), color) }
        rotate(-45f) { drawPath(sword(), color) }
    }
}

/** Avatar from the private avatars bucket, initials, or a person glyph. */
@Composable
fun BattleAvatar(name: String?, avatarPath: String? = null, size: Dp = 44.dp, modifier: Modifier = Modifier) {
    var image by remember(avatarPath) { mutableStateOf(avatarPath?.let { AvatarCache.cached(it) }) }
    LaunchedEffect(avatarPath) {
        if (avatarPath != null && image == null) image = AvatarCache.load(avatarPath)
    }
    Box(
        modifier
            .size(size)
            .clip(CircleShape)
            .background(Brush.verticalGradient(listOf(Color(0xFF33456B), Color(0xFF1C2A47))))
            .border(1.dp, Color.White.copy(alpha = 0.14f), CircleShape),
        contentAlignment = Alignment.Center
    ) {
        val img = image
        val initials = name?.takeIf { it.isNotBlank() }?.split(" ")?.take(2)?.mapNotNull { it.firstOrNull()?.toString() }?.joinToString("")?.uppercase()
        when {
            img != null -> Image(img, null, Modifier.size(size), contentScale = ContentScale.Crop)
            initials != null -> Text(initials, style = rounded((size.value * 0.36f).toInt(), FontWeight.Bold), color = Pc.ivory)
            else -> Icon(Icons.Filled.Person, null, tint = Pc.mist, modifier = Modifier.size(size * 0.45f))
        }
    }
}

object AvatarCache {
    private val images = mutableMapOf<String, ImageBitmap>()
    fun cached(path: String): ImageBitmap? = images[path]
    suspend fun load(path: String): ImageBitmap? = runCatching {
        val bytes = Backend.client.storage.from("avatars").downloadAuthenticated(path)
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size)?.asImageBitmap()?.also { images[path] = it }
    }.getOrNull()
}

/** Section label (small caps, tracked). */
@Composable
fun SectionLabel(text: String, color: Color = Pc.mist, modifier: Modifier = Modifier) {
    Text(text, style = rounded(11, FontWeight.Bold, 1.6f), color = color, modifier = modifier)
}

/** Slim capsule progress bar with gradient fill and glow. */
@Composable
fun ProgressCapsule(
    progress: Float,
    modifier: Modifier = Modifier,
    height: Dp = 10.dp,
    colors: List<Color> = listOf(Pc.progressCyan, Color(0xFF7BE9FF)),
    minFill: Dp = 10.dp,
    track: Color = Color.White.copy(alpha = 0.14f)
) {
    val animated by animateFloatAsState(progress.coerceIn(0f, 1f), spring(dampingRatio = 0.85f, stiffness = 200f), label = "progress")
    androidx.compose.foundation.layout.BoxWithConstraints(modifier.fillMaxWidth().height(height).clip(CircleShape).background(track)) {
        Box(
            Modifier
                .height(height)
                .width(maxOf(maxWidth * animated, minFill))
                .background(Brush.horizontalGradient(colors), CircleShape)
        )
    }
}

@Suppress("unused")
private val unusedScale = Modifier.scale(1f)

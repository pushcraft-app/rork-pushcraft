package com.rork.pushcraftandroid.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import com.rork.pushcraftandroid.R

/** Pushcraft palette, mirrored 1:1 from the iOS `Theme`. */
object Pc {
    val cyan = Color(0xFF27E3FF)
    val gold = Color(0xFFFFC53D)

    val ivory = Color(0xFFF5F1E6)
    val amber = Color(0xFFFFAE2A)
    val amberSoft = Color(0xFFFFC24B)
    val amberDeep = Color(0xFFFF8A1E)
    val streakOrange = Color(0xFFFF8A3D)
    val mist = Color(0xFF9DAECB)
    val progressCyan = Color(0xFF3ED6FF)
    val night = Color(0xFF050D1C)
    val towersNavy = Color(0xFF0B1426)
    val cardFill = Color(0xC70B1B33)
    val panelTint = Color(0xFF111E3A)
    val pillFill = Color.Black.copy(alpha = 0.4f)
    val pillBorder = Color(0x8C6E82A6)
    val panel = Color.Black.copy(alpha = 0.55f)
    val track = Color(0xD9071520)

    val obNavy = Color(0xFF071D42)
    val obNavyDeep = Color(0xFF030E24)
    val obCard = Color(0xFF0E2649)
    val obCardBorder = Color.White.copy(alpha = 0.12f)
    val buttonInk = Color(0xFF3A2200)
    val amberEdge = Color(0xFFB0560C)

    val paywallBg = Color(0xFF0B1830)
    val paywallGold = Color(0xFFFFD232)
    val paywallGoldDeep = Color(0xFFF6B60A)
    val paywallGoldEdge = Color(0xFFB98200)
    val paywallInk = Color(0xFF0B1630)
    val paywallSlate = Color(0xFF3A4B69)

    val battleCard = Color(0xFF121F3A)
    val battleCardBorder = Color(0xFF2B3D63)
    val iconBlue = Color(0xFFAFC3E8)
    val success = Color(0xFF3DDC84)
    val danger = Color(0xFFFF6B6B)
    val journeyTop = Color(0xFF0A1730)
}

/** Serif display face (stands in for iOS New York). */
@OptIn(androidx.compose.ui.text.ExperimentalTextApi::class)
val SerifFamily = FontFamily(
    Font(R.font.lora, FontWeight.Normal, variationSettings = FontVariation.Settings(FontVariation.weight(400))),
    Font(R.font.lora, FontWeight.Medium, variationSettings = FontVariation.Settings(FontVariation.weight(500))),
    Font(R.font.lora, FontWeight.SemiBold, variationSettings = FontVariation.Settings(FontVariation.weight(600))),
    Font(R.font.lora, FontWeight.Bold, variationSettings = FontVariation.Settings(FontVariation.weight(700))),
    Font(R.font.lora, FontWeight.ExtraBold, variationSettings = FontVariation.Settings(FontVariation.weight(700))),
    Font(R.font.lora, FontWeight.Black, variationSettings = FontVariation.Settings(FontVariation.weight(700)))
)

/** Rounded UI face (stands in for SF Rounded). */
@OptIn(androidx.compose.ui.text.ExperimentalTextApi::class)
val RoundedFamily = FontFamily(
    Font(R.font.nunito, FontWeight.Normal, variationSettings = FontVariation.Settings(FontVariation.weight(400))),
    Font(R.font.nunito, FontWeight.Medium, variationSettings = FontVariation.Settings(FontVariation.weight(500))),
    Font(R.font.nunito, FontWeight.SemiBold, variationSettings = FontVariation.Settings(FontVariation.weight(600))),
    Font(R.font.nunito, FontWeight.Bold, variationSettings = FontVariation.Settings(FontVariation.weight(700))),
    Font(R.font.nunito, FontWeight.ExtraBold, variationSettings = FontVariation.Settings(FontVariation.weight(800))),
    Font(R.font.nunito, FontWeight.Black, variationSettings = FontVariation.Settings(FontVariation.weight(900)))
)

/** Rounded text style helper mirroring `.system(size:weight:design: .rounded)`. */
fun rounded(size: Int, weight: FontWeight = FontWeight.Normal, tracking: Float = 0f): TextStyle =
    TextStyle(fontFamily = RoundedFamily, fontSize = size.sp, fontWeight = weight, letterSpacing = tracking.sp, lineHeight = (size * 1.22f).sp)

/** Serif text style helper mirroring `.system(size:weight:design: .serif)`. */
fun serif(size: Int, weight: FontWeight = FontWeight.Bold, tracking: Float = 0f): TextStyle =
    TextStyle(fontFamily = SerifFamily, fontSize = size.sp, fontWeight = weight, letterSpacing = tracking.sp, lineHeight = (size * 1.2f).sp)

/** Default sans (SF Pro) text style. */
fun sans(size: Int, weight: FontWeight = FontWeight.Normal): TextStyle =
    TextStyle(fontSize = size.sp, fontWeight = weight, lineHeight = (size * 1.22f).sp)

val TextUnit.asTracking: TextUnit get() = this

private val PushcraftScheme = darkColorScheme(
    primary = Pc.amber,
    onPrimary = Pc.buttonInk,
    secondary = Pc.progressCyan,
    background = Pc.night,
    surface = Pc.towersNavy,
    onBackground = Pc.ivory,
    onSurface = Pc.ivory,
    surfaceContainer = Pc.towersNavy,
    surfaceContainerHigh = Pc.battleCard,
    error = Pc.danger
)

@Composable
fun AppTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = PushcraftScheme, content = content)
}

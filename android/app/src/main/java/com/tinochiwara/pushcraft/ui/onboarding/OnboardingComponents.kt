package com.tinochiwara.pushcraft.ui.onboarding

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.FormatQuote
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.tinochiwara.pushcraft.data.Haptics
import com.tinochiwara.pushcraft.ui.components.pressScale
import com.tinochiwara.pushcraft.ui.theme.Pc
import com.tinochiwara.pushcraft.ui.theme.rounded
import com.tinochiwara.pushcraft.ui.theme.serif
import kotlinx.coroutines.delay

/** Deep navy canvas with a soft top glow. */
@Composable
fun OnboardingBackground() {
    Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Pc.obNavy, Pc.obNavyDeep)))) {
        Box(
            Modifier.fillMaxSize().background(
                Brush.radialGradient(listOf(Color(0x731E4A8F), Color.Transparent), center = androidx.compose.ui.geometry.Offset(540f, 230f), radius = 1100f)
            )
        )
    }
}

/** Back chevron plus questionnaire progress bar. */
@Composable
fun OnboardingTopBar(progress: Float?, canGoBack: Boolean, onBack: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        Box(
            Modifier.size(44.dp).alpha(if (canGoBack) 1f else 0f).pressScale(canGoBack) { onBack() },
            contentAlignment = Alignment.Center
        ) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = Pc.ivory, modifier = Modifier.size(22.dp)) }
        if (progress != null) {
            val p by animateFloatAsState(progress, spring(dampingRatio = 0.85f, stiffness = 150f), label = "obp")
            androidx.compose.foundation.layout.BoxWithConstraints(Modifier.weight(1f).height(6.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.12f))) {
                Box(Modifier.height(6.dp).width(maxOf(8.dp, maxWidth * p)).background(Brush.horizontalGradient(listOf(Pc.amberSoft, Pc.amberDeep)), CircleShape))
            }
        } else Spacer(Modifier.weight(1f))
        Spacer(Modifier.size(44.dp))
    }
}

/** Wide amber CTA with a darker bottom edge. */
@Composable
fun OnboardingPrimaryButton(title: String, enabled: Boolean = true, isLoading: Boolean = false, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(18.dp)
    Box(
        modifier
            .fillMaxWidth()
            .height(60.dp)
            .alpha(if (enabled) 1f else 0.45f)
            .pressScale(enabled && !isLoading) { Haptics.tap(); onClick() }
    ) {
        Box(Modifier.fillMaxWidth().height(56.dp).offset(y = 4.dp).background(Pc.amberEdge, shape))
        Box(
            Modifier.fillMaxWidth().height(56.dp)
                .shadow(if (enabled) 14.dp else 0.dp, shape, ambientColor = Pc.amberDeep, spotColor = Pc.amberDeep)
                .background(Brush.verticalGradient(listOf(Pc.amberSoft, Pc.amberDeep)), shape),
            contentAlignment = Alignment.Center
        ) {
            if (isLoading) CircularProgressIndicator(Modifier.size(22.dp), color = Pc.buttonInk, strokeWidth = 2.5.dp)
            else Text(title, style = rounded(19, FontWeight.Bold), color = Pc.buttonInk)
        }
    }
}

@Composable
fun OnboardingSecondaryButton(title: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(modifier.fillMaxWidth().heightIn(min = 44.dp).pressScale { Haptics.tap(); onClick() }, contentAlignment = Alignment.Center) {
        Text(title, style = rounded(16, FontWeight.SemiBold), color = Pc.mist)
    }
}

/** Pinned bottom CTA shared by every onboarding step. */
@Composable
fun PersistentCTA(
    title: String,
    enabled: Boolean,
    isLoading: Boolean,
    secondaryTitle: String?,
    onPrimary: () -> Unit,
    onSecondary: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier
            .fillMaxWidth()
            .background(Brush.verticalGradient(0f to Pc.obNavyDeep.copy(alpha = 0f), 0.45f to Pc.obNavyDeep.copy(alpha = 0.9f), 1f to Pc.obNavyDeep))
            .navigationBarsPadding()
            .padding(start = 24.dp, end = 24.dp, top = 8.dp, bottom = 12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        secondaryTitle?.let { OnboardingSecondaryButton(it, onClick = onSecondary) }
        OnboardingPrimaryButton(title, enabled, isLoading, onClick = onPrimary)
    }
}

@Composable
fun OnboardingHeader(title: String, helper: String? = null, modifier: Modifier = Modifier) {
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(title, style = serif(30), color = Pc.ivory)
        helper?.let { Text(it, style = rounded(16, FontWeight.Medium), color = Pc.mist) }
    }
}

/** Standard question screen: heading, helper, content; leaves CTA clearance. */
@Composable
fun OnboardingScaffold(title: String, helper: String? = null, scrolls: Boolean = true, content: @Composable () -> Unit) {
    val base = Modifier.fillMaxSize()
    Column(
        (if (scrolls) base.verticalScroll(rememberScrollState()) else base)
            .padding(horizontal = 24.dp)
            .padding(top = 12.dp, bottom = if (scrolls) 140.dp else 110.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        OnboardingHeader(title, helper)
        content()
    }
}

/** Tappable answer card. */
@Composable
fun OnboardingOptionRow(title: String, icon: ImageVector?, isSelected: Boolean, isMulti: Boolean = false, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(18.dp)
    val scale by animateFloatAsState(if (isSelected) 1f else 0.985f, spring(dampingRatio = 0.7f), label = "opt")
    Row(
        modifier
            .fillMaxWidth()
            .scale(scale)
            .heightIn(min = 60.dp)
            .background(if (isSelected) Pc.amberSoft.copy(alpha = 0.12f) else Pc.obCard.copy(alpha = 0.85f), shape)
            .border(if (isSelected) 2.dp else 1.dp, if (isSelected) Pc.amberSoft else Pc.obCardBorder, shape)
            .pressScale { Haptics.selection(); onClick() }
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        if (icon != null) {
            Box(
                Modifier.size(40.dp).background(if (isSelected) Pc.amberSoft else Pc.amberSoft.copy(alpha = 0.12f), RoundedCornerShape(12.dp)),
                contentAlignment = Alignment.Center
            ) { Icon(icon, null, tint = if (isSelected) Pc.buttonInk else Pc.amberSoft, modifier = Modifier.size(20.dp)) }
        }
        Text(title, style = rounded(17, FontWeight.SemiBold), color = Pc.ivory, modifier = Modifier.weight(1f))
        val indicatorShape = if (isMulti) RoundedCornerShape(7.dp) else CircleShape
        Box(
            Modifier.size(24.dp)
                .background(if (isSelected) Pc.amberSoft else Color.Transparent, indicatorShape)
                .border(2.dp, if (isSelected) Pc.amberSoft else Color.White.copy(alpha = 0.3f), indicatorShape),
            contentAlignment = Alignment.Center
        ) {
            if (isSelected) Icon(Icons.Filled.Check, null, tint = Pc.buttonInk, modifier = Modifier.size(14.dp))
        }
    }
}

/** Quote-style card for the statement questions. */
@Composable
fun StatementCard(text: String) {
    val shape = RoundedCornerShape(22.dp)
    Row(Modifier.fillMaxWidth().clip(shape).background(Pc.obCard).border(1.dp, Pc.obCardBorder, shape)) {
        Box(Modifier.width(5.dp).height(150.dp).background(Pc.amberSoft))
        Column(Modifier.padding(22.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Icon(Icons.Filled.FormatQuote, null, tint = Pc.amberSoft, modifier = Modifier.size(26.dp))
            Text(text, style = serif(21, FontWeight.SemiBold), color = Pc.ivory)
        }
    }
}

/** The golem's speech bubble with an optional typewriter reveal. */
@Composable
fun SpeechBubble(text: String, modifier: Modifier = Modifier, fontSize: Int = 19, typewriter: Boolean = true, tailLeading: Boolean = false) {
    var visible by remember(text) { mutableIntStateOf(if (typewriter) 0 else text.length) }
    LaunchedEffect(text) {
        if (!typewriter) return@LaunchedEffect
        for (i in 1..text.length) {
            delay(22)
            visible = i
        }
    }
    Box(modifier) {
        Box(
            Modifier
                .shadow(16.dp, RoundedCornerShape(20.dp))
                .background(Pc.ivory, RoundedCornerShape(20.dp))
                .padding(horizontal = 18.dp, vertical = 14.dp)
        ) {
            Text(text, style = rounded(fontSize, FontWeight.SemiBold), color = Color.Transparent)
            Text(text.take(visible), style = rounded(fontSize, FontWeight.SemiBold), color = Pc.paywallInk)
        }
        androidx.compose.foundation.Canvas(
            Modifier
                .align(if (tailLeading) Alignment.TopStart else Alignment.BottomStart)
                .offset(x = if (tailLeading) (-12).dp else 40.dp, y = if (tailLeading) 22.dp else 12.dp)
                .size(22.dp, 14.dp)
        ) {
            val p = androidx.compose.ui.graphics.Path()
            if (tailLeading) {
                p.moveTo(size.width, 0f); p.lineTo(size.width, size.height); p.lineTo(0f, size.height * 0.4f)
            } else {
                p.moveTo(0f, 0f); p.lineTo(size.width, 0f); p.lineTo(size.width * 0.35f, size.height)
            }
            p.close()
            drawPath(p, Pc.ivory)
        }
    }
}

/** Terms / Privacy line under sign-in buttons. */
@Composable
fun LegalLine() {
    val uri = LocalUriHandler.current
    val text = buildAnnotatedString {
        append("By continuing, you agree to our ")
        pushStringAnnotation("url", "https://www.pushcraft.app/terms")
        pushStyle(SpanStyle(color = Pc.amberSoft)); append("Terms of Service"); pop(); pop()
        append(" and ")
        pushStringAnnotation("url", "https://www.pushcraft.app/privacy-policy")
        pushStyle(SpanStyle(color = Pc.amberSoft)); append("Privacy Policy"); pop(); pop()
        append(".")
    }
    @Suppress("DEPRECATION")
    androidx.compose.foundation.text.ClickableText(
        text, style = rounded(12, FontWeight.Medium).copy(color = Pc.mist.copy(alpha = 0.8f), textAlign = TextAlign.Center),
        modifier = Modifier.fillMaxWidth()
    ) { offset ->
        text.getStringAnnotations("url", offset, offset).firstOrNull()?.let { uri.openUri(it.item) }
    }
}

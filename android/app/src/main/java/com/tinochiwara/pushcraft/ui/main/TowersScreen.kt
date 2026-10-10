package com.tinochiwara.pushcraft.ui.main

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PageSize
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Construction
import androidx.compose.material.icons.filled.DonutLarge
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import com.tinochiwara.pushcraft.data.AppState
import com.tinochiwara.pushcraft.data.Haptics
import com.tinochiwara.pushcraft.data.Progress
import com.tinochiwara.pushcraft.model.Tower
import com.tinochiwara.pushcraft.model.TowerStatus
import com.tinochiwara.pushcraft.ui.components.CountersRow
import com.tinochiwara.pushcraft.ui.components.GoldButton
import com.tinochiwara.pushcraft.ui.components.ProgressCapsule
import com.tinochiwara.pushcraft.ui.components.TowerConstructionView
import com.tinochiwara.pushcraft.ui.components.pressScale
import com.tinochiwara.pushcraft.ui.theme.Pc
import com.tinochiwara.pushcraft.ui.theme.rounded
import com.tinochiwara.pushcraft.ui.theme.serif
import kotlin.math.absoluteValue

/** Towers tab: snapping carousel of every tower plus a coming-soon card. */
@Composable
fun TowersScreen(appState: AppState, nav: NavController, modifier: Modifier = Modifier) {
    val dashboard by appState.progress.dashboard.collectAsState()
    val towers = Progress.towers(dashboard)
    val home = Progress.homeData(dashboard)
    var lockedMessage by remember { mutableStateOf<String?>(null) }
    val currentIndex = towers.indexOfFirst { it.id == Progress.currentTowerId(towers) }.coerceAtLeast(0)
    val pager = rememberPagerState(initialPage = currentIndex) { towers.size + 1 }
    LaunchedEffect(towers.size) { if (towers.isNotEmpty()) pager.scrollToPage(currentIndex) }
    LaunchedEffect(pager.currentPage) { Haptics.tick() }

    Column(modifier.fillMaxSize().background(Pc.towersNavy).statusBarsPadding().verticalScroll(rememberScrollState()).padding(top = 8.dp, bottom = 28.dp)) {
        Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            CountersRow(home.streak, home.xp, home.coinsDisplay)
            Text("Towers", style = serif(34), color = Pc.ivory, modifier = Modifier.padding(top = 14.dp))
            Text("One rep. One block higher.", style = rounded(16, FontWeight.Medium), color = Pc.mist)
        }
        BoxWithConstraints(Modifier.fillMaxWidth().padding(top = 10.dp)) {
            val cardWidth = minOf(250.dp, maxWidth * 0.62f)
            val inset = (maxWidth - cardWidth) / 2
            HorizontalPager(
                pager, pageSize = PageSize.Fixed(cardWidth), contentPadding = PaddingValues(horizontal = inset),
                pageSpacing = 16.dp, modifier = Modifier.height(430.dp)
            ) { page ->
                val offset = ((pager.currentPage - page) + pager.currentPageOffsetFraction).absoluteValue.coerceIn(0f, 1f)
                val mod = Modifier.fillMaxSize().padding(vertical = 10.dp).scale(1f - 0.1f * offset).alpha(1f - 0.3f * offset)
                if (page < towers.size) {
                    val tower = towers[page]
                    TowerCard(tower, mod) {
                        if (tower.status == TowerStatus.Locked) {
                            lockedMessage = "Complete ${tower.unlockedAfter ?: "the previous tower"} to unlock ${tower.name}."
                        } else nav.navigate("journey/${tower.id}")
                    }
                } else ComingSoonCard(mod)
            }
        }
        Box(Modifier.padding(horizontal = 20.dp).padding(top = 26.dp).fillMaxWidth().height(1.dp).background(Color.White.copy(alpha = 0.1f)))
        GoldButton(
            "Continue building", Modifier.padding(horizontal = 20.dp).padding(top = 20.dp), height = 56.dp, radius = 18.dp, textSize = 20,
            icon = null
        ) { nav.navigate("prep") }
    }

    lockedMessage?.let { msg ->
        AlertDialog(
            onDismissRequest = { lockedMessage = null }, containerColor = Pc.towersNavy,
            title = { Text("Tower locked", style = rounded(19, FontWeight.Bold), color = Pc.ivory) },
            text = { Text(msg, style = rounded(15, FontWeight.Medium), color = Pc.mist) },
            confirmButton = { TextButton({ lockedMessage = null }) { Text("OK", color = Pc.amberSoft) } }
        )
    }
}

@Composable
private fun TowerCard(tower: Tower, modifier: Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(24.dp)
    val inProgress = tower.status == TowerStatus.InProgress
    Column(
        modifier
            .shadow(16.dp, shape, ambientColor = if (inProgress) Pc.amber else Color.Black, spotColor = if (inProgress) Pc.amber else Color.Black)
            .background(Color(if (inProgress) 0xFF131F38 else 0xFF111B2F), shape)
            .then(if (inProgress) Modifier.border(1.5.dp, Brush.linearGradient(listOf(Pc.amberSoft.copy(alpha = 0.9f), Pc.amberDeep.copy(alpha = 0.7f))), shape) else Modifier)
            .pressScale { Haptics.tap(); onClick() }
            .padding(horizontal = 14.dp).padding(bottom = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        StatusBadge(tower.status, Modifier.padding(top = 14.dp))
        Box(Modifier.padding(top = 14.dp).height(210.dp).fillMaxWidth(), contentAlignment = Alignment.Center) {
            TowerConstructionView(tower.id, tower.builtStages, tower.stageFraction, tower.status == TowerStatus.Locked)
            if (tower.status == TowerStatus.Locked) Icon(Icons.Filled.Lock, null, tint = Color.White.copy(alpha = 0.85f), modifier = Modifier.size(36.dp))
        }
        Text(tower.name, style = serif(21), color = Pc.ivory, maxLines = 1, modifier = Modifier.padding(top = 12.dp))
        Text(
            when (tower.status) {
                TowerStatus.Completed -> "All ${tower.totalStages} stages built"
                TowerStatus.InProgress -> "Stage ${tower.currentStage} of ${tower.totalStages}"
                TowerStatus.Locked -> "${tower.totalStages} stages · ${tower.totalReps} reps"
            },
            style = rounded(15, FontWeight.SemiBold), color = Pc.mist, modifier = Modifier.padding(top = 3.dp)
        )
        if (tower.progress > 0) {
            ProgressCapsule(
                tower.progress.toFloat(), Modifier.padding(top = 12.dp), minFill = 12.dp,
                colors = if (tower.status == TowerStatus.Completed) listOf(Color(0xFF4ADE80), Color(0xFF22B45E)) else listOf(Pc.amberSoft, Pc.amberDeep)
            )
        } else {
            Box(Modifier.padding(top = 12.dp).fillMaxWidth().height(10.dp).background(Color.White.copy(alpha = 0.14f), CircleShape))
        }
        Text("${tower.percentComplete}% complete", style = rounded(13, FontWeight.Medium), color = Pc.mist, modifier = Modifier.padding(top = 8.dp))
    }
}

@Composable
fun StatusBadge(status: TowerStatus, modifier: Modifier = Modifier) {
    val (label, icon, color) = when (status) {
        TowerStatus.Completed -> Triple("COMPLETED", Icons.Filled.CheckCircle, Pc.success)
        TowerStatus.InProgress -> Triple("IN PROGRESS", Icons.Filled.DonutLarge, Pc.amberSoft)
        TowerStatus.Locked -> Triple("LOCKED", Icons.Filled.Lock, Color(0xFF97A3B8))
    }
    Row(
        modifier.background(color.copy(alpha = 0.14f), CircleShape).border(1.dp, color.copy(alpha = 0.55f), CircleShape).padding(horizontal = 12.dp, vertical = 7.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Icon(icon, null, tint = color, modifier = Modifier.size(12.dp))
        Text(label, style = rounded(12, FontWeight.Bold, 0.8f), color = color)
    }
}

@Composable
private fun ComingSoonCard(modifier: Modifier) {
    Column(
        modifier
            .background(Pc.panel.copy(alpha = 0.25f), RoundedCornerShape(24.dp))
            .drawBehind {
                drawRoundRect(
                    Color.White.copy(alpha = 0.16f), cornerRadius = androidx.compose.ui.geometry.CornerRadius(24.dp.toPx()),
                    style = Stroke(1.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(7.dp.toPx(), 6.dp.toPx())))
                )
            },
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterVertically)
    ) {
        Icon(Icons.Filled.Construction, null, tint = Pc.amberSoft.copy(alpha = 0.85f), modifier = Modifier.size(34.dp))
        Text("Coming soon", style = serif(21), color = Pc.ivory.copy(alpha = 0.9f))
        Text("More towers on the way", style = rounded(15, FontWeight.Medium), color = Pc.mist)
    }
}

@Suppress("unused")
private val keep = Icons.AutoMirrored.Filled.KeyboardArrowRight

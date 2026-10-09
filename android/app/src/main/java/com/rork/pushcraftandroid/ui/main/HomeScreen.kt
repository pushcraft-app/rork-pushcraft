package com.rork.pushcraftandroid.ui.main

import androidx.compose.foundation.Image
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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.CloudUpload
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Signpost
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import com.rork.pushcraftandroid.R
import com.rork.pushcraftandroid.data.AppState
import com.rork.pushcraftandroid.data.Progress
import com.rork.pushcraftandroid.model.TowerStatus
import com.rork.pushcraftandroid.ui.components.CountersRow
import com.rork.pushcraftandroid.ui.components.GoldButton
import com.rork.pushcraftandroid.ui.components.ProgressCapsule
import com.rork.pushcraftandroid.ui.components.TowerConstructionView
import com.rork.pushcraftandroid.ui.components.pressScale
import com.rork.pushcraftandroid.ui.theme.Pc
import com.rork.pushcraftandroid.ui.theme.rounded
import com.rork.pushcraftandroid.ui.theme.serif
import kotlinx.coroutines.launch

/** Home: what's being built, current stage progress, and the next workout. */
@Composable
fun HomeScreen(appState: AppState, nav: NavController, modifier: Modifier = Modifier) {
    val dashboard by appState.progress.dashboard.collectAsState()
    val pending by appState.workouts.pending.collectAsState()
    val syncing by appState.workouts.isSyncing.collectAsState()
    val data = Progress.homeData(dashboard)
    val towers = Progress.towers(dashboard)
    val current = towers.firstOrNull { it.status == TowerStatus.InProgress } ?: towers.lastOrNull { it.status == TowerStatus.Completed }
    val scroll = rememberScrollState()
    val scope = rememberCoroutineScope()
    var refreshing by remember { mutableStateOf(false) }
    val unsynced = appState.workouts.unsyncedCount(pending)

    Box(modifier.fillMaxSize().background(Pc.night)) {
        Image(painterResource(R.drawable.fantasy_castle_night_bg), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
        Box(
            Modifier.fillMaxSize().background(
                Brush.verticalGradient(
                    0f to Color.Black.copy(alpha = 0.4f), 0.22f to Color.Black.copy(alpha = 0.05f),
                    0.62f to Color.Black.copy(alpha = 0.1f), 1f to Pc.night.copy(alpha = 0.85f)
                )
            )
        )
        // Fixed tower with parallax.
        Column(
            Modifier.fillMaxWidth().statusBarsPadding().padding(top = 8.dp + 132.dp).graphicsLayer { translationY = -scroll.value * 0.35f },
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Box(
                Modifier.height(26.dp).background(Pc.pillFill, CircleShape).border(1.dp, Pc.pillBorder, CircleShape).padding(horizontal = 12.dp),
                contentAlignment = Alignment.Center
            ) { Text("YOUR CURRENT TOWER", style = rounded(10, FontWeight.Bold, 2f), color = Pc.ivory.copy(alpha = 0.95f)) }
            TowerConstructionView(current?.id ?: data.towerName, current?.builtStages ?: 0, current?.stageFraction ?: 0.0, modifier = Modifier.height(400.dp))
        }
        PullToRefreshBox(
            isRefreshing = refreshing,
            onRefresh = { scope.launch { refreshing = true; appState.refresh(); refreshing = false } },
            modifier = Modifier.fillMaxSize()
        ) {
            Column(Modifier.fillMaxSize().verticalScroll(scroll).statusBarsPadding().padding(top = 8.dp)) {
                Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    CountersRow(data.streak, data.xp, data.coinsDisplay)
                    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text("Build strength.", style = serif(26), color = Pc.ivory, maxLines = 1)
                        Text("Craft your tower.", style = serif(26), color = Pc.ivory, maxLines = 1)
                    }
                }
                Spacer(Modifier.height(14.dp + 26.dp + 252.dp))
                Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 28.dp)) {
                    Column(
                        Modifier.fillMaxWidth()
                            .background(
                                Brush.verticalGradient(
                                    0f to Pc.panelTint.copy(alpha = 0f), 0.22f to Pc.panelTint.copy(alpha = 0.15f),
                                    0.5f to Pc.panelTint.copy(alpha = 0.65f), 0.74f to Pc.panelTint.copy(alpha = 0.45f), 1f to Pc.panelTint.copy(alpha = 0f)
                                )
                            )
                            .padding(top = 22.dp, bottom = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Text(data.towerName, style = serif(29), color = Pc.ivory, maxLines = 1)
                        Text("Stage ${data.stageNumber} of ${data.totalStages} · ${data.stageName}", style = rounded(16, FontWeight.SemiBold), color = Pc.mist, maxLines = 1)
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            ProgressCapsule(data.stageProgress.toFloat(), Modifier.weight(1f), height = 13.dp, minFill = 14.dp, track = Color.White.copy(alpha = 0.16f))
                            Text("${data.stagePercent}%", style = rounded(22, FontWeight.Bold), color = Pc.progressCyan)
                        }
                        Text(
                            if (data.isAllComplete) "Every tower built — bonus reps still count"
                            else "${data.repsIntoStage} of ${data.stageTarget} reps · ${data.repsToGo} to go",
                            style = rounded(15, FontWeight.Medium), color = Pc.mist
                        )
                    }
                    if (unsynced > 0) {
                        Row(
                            Modifier.padding(top = 12.dp).fillMaxWidth().background(Pc.cardFill, RoundedCornerShape(16.dp))
                                .border(1.dp, Pc.amberSoft.copy(alpha = 0.45f), RoundedCornerShape(16.dp)).padding(horizontal = 14.dp, vertical = 11.dp),
                            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            Icon(Icons.Filled.CloudUpload, null, tint = Pc.amberSoft, modifier = Modifier.size(17.dp))
                            Text(if (unsynced == 1) "1 workout waiting to sync" else "$unsynced workouts waiting to sync", style = rounded(14, FontWeight.SemiBold), color = Pc.ivory, modifier = Modifier.weight(1f))
                            Text(
                                if (syncing) "Syncing…" else "Sync now", style = rounded(13, FontWeight.Bold), color = Pc.amberSoft,
                                modifier = Modifier.pressScale(!syncing) { scope.launch { appState.refresh() } }
                            )
                        }
                    }
                    GoldButton(
                        "Start Workout", Modifier.padding(top = 12.dp), height = 58.dp, radius = 18.dp, textSize = 22,
                        icon = { Icon(Icons.Filled.PlayArrow, null, tint = Pc.buttonInk, modifier = Modifier.size(24.dp)) }
                    ) { nav.navigate("prep") }
                    Row(
                        Modifier.padding(top = 12.dp).align(Alignment.CenterHorizontally).pressScale { nav.navigate("trail") }.padding(10.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Icon(Icons.Filled.Signpost, null, tint = Pc.ivory.copy(alpha = 0.92f), modifier = Modifier.size(17.dp))
                        Text("View journey", style = rounded(17, FontWeight.SemiBold), color = Pc.ivory.copy(alpha = 0.92f))
                        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Pc.ivory.copy(alpha = 0.92f), modifier = Modifier.size(18.dp))
                    }
                }
            }
        }
    }
}

@Suppress("unused")
private val keep = Modifier.offset(0.dp)

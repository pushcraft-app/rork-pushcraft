package com.rork.pushcraftandroid.ui.main

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.SelfImprovement
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import com.rork.pushcraftandroid.R
import com.rork.pushcraftandroid.data.AppState
import com.rork.pushcraftandroid.data.Haptics
import com.rork.pushcraftandroid.data.Progress
import com.rork.pushcraftandroid.data.WorkoutException
import com.rork.pushcraftandroid.model.Exercise
import com.rork.pushcraftandroid.model.JourneyStage
import com.rork.pushcraftandroid.model.StageState
import com.rork.pushcraftandroid.model.Tower
import com.rork.pushcraftandroid.model.TowerStatus
import com.rork.pushcraftandroid.ui.components.BackTextButton
import com.rork.pushcraftandroid.ui.components.GoldButton
import com.rork.pushcraftandroid.ui.components.ProgressCapsule
import com.rork.pushcraftandroid.ui.components.TowerArt
import com.rork.pushcraftandroid.ui.components.TowerParts
import com.rork.pushcraftandroid.ui.components.pressScale
import com.rork.pushcraftandroid.ui.theme.Pc
import com.rork.pushcraftandroid.ui.theme.rounded
import com.rork.pushcraftandroid.ui.theme.serif
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.sin

private const val MAP_W = 852f
private const val MAP_H = 1847f

/** Card + label centers in map pixels, first tower at the bottom. */
private val trailSlots = listOf(
    Offset(237f, 1376f) to Offset(245f, 1488f),
    Offset(606f, 1125f) to Offset(609f, 1223f),
    Offset(235f, 877f) to Offset(237f, 975f),
    Offset(607f, 626f) to Offset(607f, 706f),
    Offset(235f, 356f) to Offset(235f, 458f)
)

/** Tower Trail: painted map covering the whole phone with live tower cards. */
@Composable
fun TowerTrailScreen(appState: AppState, nav: NavController) {
    val dashboard by appState.progress.dashboard.collectAsState()
    val towers = Progress.towers(dashboard)
    val currentId = Progress.currentTowerId(towers)
    var hintId by remember { mutableStateOf<String?>(null) }
    val shake = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()

    BoxWithConstraints(Modifier.fillMaxSize().background(Pc.night)) {
        val scale = maxOf(maxWidth.value / MAP_W, maxHeight.value / MAP_H)
        val mapW = MAP_W * scale
        val mapH = MAP_H * scale
        val left = (maxWidth.value - mapW) / 2
        val top = (maxHeight.value - mapH) / 2
        Image(
            painterResource(R.drawable.trail_painted_map), null, contentScale = ContentScale.FillBounds,
            modifier = Modifier.wrapContentSize(unbounded = true, align = Alignment.TopStart).offset(left.dp, top.dp).requiredSize(mapW.dp, mapH.dp)
        )
        val nodeSize = MAP_W * scale * 0.25f
        towers.forEachIndexed { index, tower ->
            val (card, label) = trailSlots[minOf(index, trailSlots.lastIndex)]
            val cx = left + card.x * scale
            val cy = top + card.y * scale
            TrailNode(
                tower = tower,
                isCurrent = tower.id == currentId,
                size = nodeSize.dp,
                labelDy = ((label.y - card.y) * scale).dp,
                labelDx = ((label.x - card.x) * scale).dp,
                shakeX = if (hintId == tower.id) (sin(shake.value * Math.PI * 4) * nodeSize * 0.06).toFloat() else 0f,
                showsHint = hintId == tower.id,
                modifier = Modifier.offset((cx - nodeSize / 2).dp, (cy - nodeSize / 2).dp)
            ) {
                if (tower.status == TowerStatus.Locked) {
                    Haptics.warning()
                    hintId = tower.id
                    scope.launch {
                        shake.snapTo(0f)
                        shake.animateTo(1f, tween(550, easing = LinearEasing))
                    }
                    scope.launch {
                        val id = tower.id
                        delay(2400)
                        if (hintId == id) hintId = null
                    }
                } else {
                    Haptics.tap()
                    hintId = null
                    nav.navigate("journey/${tower.id}")
                }
            }
        }
        Box(
            Modifier.statusBarsPadding().padding(start = 20.dp, top = 6.dp).size(44.dp)
                .shadow(6.dp, CircleShape).background(Pc.panel, CircleShape).border(1.dp, Color.White.copy(alpha = 0.18f), CircleShape)
                .pressScale { nav.popBackStack() },
            contentAlignment = Alignment.Center
        ) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = Pc.ivory, modifier = Modifier.size(20.dp)) }
    }
}

@Composable
private fun TrailNode(
    tower: Tower,
    isCurrent: Boolean,
    size: Dp,
    labelDx: Dp,
    labelDy: Dp,
    shakeX: Float,
    showsHint: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    val locked = tower.status == TowerStatus.Locked
    val completed = tower.status == TowerStatus.Completed
    val shape = RoundedCornerShape(size * 0.24f)
    val pulse = rememberInfiniteTransition(label = "glow")
    val g by pulse.animateFloat(0.92f, 1.08f, infiniteRepeatable(tween(1400), RepeatMode.Reverse), label = "g")
    Box(modifier.size(size).graphicsLayer { translationX = shakeX * density }) {
        if (isCurrent) {
            Box(
                Modifier.requiredSize(size * 1.45f).align(Alignment.Center).graphicsLayer { scaleX = g; scaleY = g }
                    .background(Brush.radialGradient(listOf(Pc.amberSoft.copy(alpha = 0.55f), Color.Transparent)), CircleShape)
            )
        }
        Box(
            Modifier.fillMaxSize()
                .shadow(if (locked) 6.dp else 12.dp, shape, ambientColor = if (locked) Color.Black else Pc.amberSoft, spotColor = if (locked) Color.Black else Pc.amberSoft)
                .clip(shape)
                .border(
                    maxOf(4.dp, size * 0.05f),
                    Brush.verticalGradient(if (locked) listOf(Color(0xFFF2F5FA), Color(0xFF8E99A8)) else listOf(Color(0xFFFFE9A8), Color(0xFFD99A2B))),
                    shape
                )
                .pressScale(onClick = onClick)
        ) {
            Image(
                painterResource(TowerParts.cardRes(TowerArt.key(tower.id))), tower.name,
                contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize().padding(maxOf(4.dp, size * 0.05f)).clip(RoundedCornerShape(size * 0.19f))
            )
        }
        if (locked || completed) {
            Box(
                Modifier.size(size * 0.34f).align(Alignment.Center).offset(size * 0.34f, size * 0.34f)
                    .shadow(4.dp, CircleShape)
                    .background(if (locked) Color(0xF023262E) else Pc.amberSoft, CircleShape)
                    .border(1.5.dp, Color.White.copy(alpha = 0.35f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(if (locked) Icons.Filled.Lock else Icons.Filled.Check, null, tint = if (locked) Color.White else Pc.buttonInk, modifier = Modifier.size(size * 0.17f))
            }
        }
        Text(
            tower.name,
            style = serif(maxOf(16, (size.value * 0.2f).toInt()), FontWeight.ExtraBold).copy(shadow = Shadow(Color.Black.copy(alpha = 0.95f), Offset(0f, 2f), 8f)),
            color = Color.White, maxLines = 1, softWrap = false,
            modifier = Modifier.align(Alignment.Center).wrapContentSize(unbounded = true).offset(labelDx, labelDy)
        )
        AnimatedVisibility(
            showsHint, enter = scaleIn(initialScale = 0.8f) + fadeIn(), exit = fadeOut(),
            modifier = Modifier.align(Alignment.TopCenter).wrapContentSize(unbounded = true).offset(y = -(size * 0.62f))
        ) {
            Text(
                "Finish ${tower.unlockedAfter ?: "the previous tower"} to unlock", style = rounded(13, FontWeight.SemiBold), color = Pc.ivory, maxLines = 1,
                modifier = Modifier.shadow(6.dp, CircleShape).background(Color(0xFF14244A), CircleShape)
                    .border(1.dp, Pc.amberSoft.copy(alpha = 0.6f), CircleShape).padding(horizontal = 12.dp, vertical = 7.dp)
            )
        }
    }
}

/** Journey: every construction stage of a tower as a timeline. */
@Composable
fun JourneyScreen(appState: AppState, towerId: String?, nav: NavController) {
    val dashboard by appState.progress.dashboard.collectAsState()
    val data = if (towerId != null) Progress.homeData(dashboard, towerId) else Progress.homeData(dashboard)
    Column(
        Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Pc.journeyTop, Pc.night))).statusBarsPadding()
            .verticalScroll(rememberScrollState()).padding(16.dp).padding(bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(22.dp)
    ) {
        BackTextButton { nav.popBackStack() }
        Column(Modifier.padding(top = 6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("YOUR JOURNEY", style = rounded(12, FontWeight.Bold, 2.4f), color = Pc.mist)
            Text(data.towerName, style = serif(30), color = Pc.ivory)
            Text("Stage ${data.stageNumber} of ${data.totalStages} · building ${data.stageName}", style = rounded(15, FontWeight.Medium), color = Pc.mist)
        }
        Column(Modifier.padding(top = 4.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
            data.journey.forEach { StageRow(it) }
        }
    }
}

@Composable
private fun StageRow(stage: JourneyStage) {
    val locked = stage.state == StageState.Locked
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Box(Modifier.size(44.dp), contentAlignment = Alignment.Center) {
                when (stage.state) {
                    StageState.Completed -> {
                        Box(Modifier.fillMaxSize().background(Pc.progressCyan.copy(alpha = 0.9f), CircleShape))
                        Icon(Icons.Filled.Check, null, tint = Color(0xFF062330), modifier = Modifier.size(20.dp))
                    }
                    StageState.Current -> {
                        Box(Modifier.fillMaxSize().background(Pc.cardFill, CircleShape).border(2.dp, Pc.progressCyan, CircleShape))
                        Text("${stage.number}", style = rounded(17, FontWeight.ExtraBold), color = Pc.progressCyan)
                    }
                    StageState.Locked -> {
                        Box(Modifier.fillMaxSize().background(Pc.cardFill, CircleShape).border(1.5.dp, Color.White.copy(alpha = 0.12f), CircleShape))
                        Icon(Icons.Filled.Lock, null, tint = Pc.mist.copy(alpha = 0.6f), modifier = Modifier.size(16.dp))
                    }
                }
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text("Stage ${stage.number} · ${stage.name}", style = rounded(17, FontWeight.Bold), color = if (locked) Pc.mist.copy(alpha = 0.55f) else Pc.ivory)
                Text(
                    when (stage.state) {
                        StageState.Completed -> "Construction complete"
                        StageState.Current -> "${stage.repsDone} of ${stage.repsRequired} reps"
                        StageState.Locked -> "${stage.repsRequired} reps · unlocks after the previous stage"
                    },
                    style = rounded(13, FontWeight.Medium), color = Pc.mist.copy(alpha = if (locked) 0.6f else 1f)
                )
            }
            Text(
                when (stage.state) { StageState.Completed -> "COMPLETED"; StageState.Current -> "IN PROGRESS"; StageState.Locked -> "LOCKED" },
                style = rounded(11, FontWeight.Bold, 1.4f),
                color = when (stage.state) { StageState.Completed -> Pc.progressCyan; StageState.Current -> Pc.amber; StageState.Locked -> Pc.mist.copy(alpha = 0.55f) }
            )
        }
        if (stage.state == StageState.Current) {
            Column(Modifier.padding(start = 58.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                ProgressCapsule(stage.progress.toFloat())
                Text("${maxOf(stage.repsRequired - stage.repsDone, 0)} reps to finish ${stage.name}", style = rounded(12, FontWeight.SemiBold), color = Pc.mist)
            }
        }
    }
}

/** Session details; Start registers the workout online, then opens the arena. */
@Composable
fun WorkoutPrepScreen(appState: AppState, nav: NavController, host: WorkoutHost) {
    val dashboard by appState.progress.dashboard.collectAsState()
    val data = Progress.homeData(dashboard)
    var exercise by remember { mutableStateOf(Exercise.PushUps) }
    var starting by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    Column(
        Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Pc.journeyTop, Pc.night))).statusBarsPadding()
            .verticalScroll(rememberScrollState()).padding(16.dp).padding(bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        BackTextButton { nav.popBackStack() }
        Column(Modifier.padding(top = 6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("YOUR SESSION", style = rounded(12, FontWeight.Bold, 2.4f), color = Pc.mist)
            Text(if (data.isAllComplete) "Bonus workout" else "Stage ${data.stageNumber} of ${data.totalStages}", style = serif(30), color = Pc.ivory)
            Text(
                if (data.isAllComplete) "Every tower is built — reps still count toward your stats" else "${data.towerName} · ${data.stageName}",
                style = rounded(15, FontWeight.Medium), color = Pc.mist
            )
        }
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("CHOOSE YOUR EXERCISE", style = rounded(12, FontWeight.Bold, 2.4f), color = Pc.mist)
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                listOf(Exercise.PushUps to Icons.Filled.FitnessCenter, Exercise.SitUps to Icons.Filled.SelfImprovement).forEach { (option, icon) ->
                    val sel = exercise == option
                    val shape = RoundedCornerShape(16.dp)
                    Row(
                        Modifier.weight(1f).height(54.dp)
                            .shadow(if (sel) 8.dp else 0.dp, shape, ambientColor = Pc.amber, spotColor = Pc.amber)
                            .background(if (sel) Brush.verticalGradient(listOf(Pc.amberSoft, Pc.amberDeep)) else Brush.verticalGradient(listOf(Pc.cardFill, Pc.cardFill)), shape)
                            .border(1.dp, if (sel) Color.Transparent else Pc.pillBorder, shape)
                            .pressScale { exercise = option }.padding(horizontal = 14.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Icon(icon, null, tint = if (sel) Pc.buttonInk else Pc.iconBlue, modifier = Modifier.size(24.dp))
                        Text(option.displayName, style = rounded(16, FontWeight.Bold), color = if (sel) Pc.buttonInk else Pc.ivory)
                    }
                }
            }
            Text("Either exercise earns reps toward any tower.", style = rounded(12, FontWeight.Medium), color = Pc.mist.copy(alpha = 0.8f))
        }
        Column(Modifier.background(Pc.cardFill, RoundedCornerShape(20.dp)).border(1.dp, Pc.pillBorder, RoundedCornerShape(20.dp))) {
            DetailRow(
                { Icon(Icons.Filled.FitnessCenter, null, tint = Pc.ivory.copy(alpha = 0.9f), modifier = Modifier.size(20.dp)) },
                "${data.sets} sets × ${data.repsPerSet} ${exercise.unitName}", "${data.totalPlannedReps} reps completes the workout · keep going for more"
            )
            Divider()
            DetailRow(
                { Icon(Icons.Filled.AutoAwesome, null, tint = Pc.ivory.copy(alpha = 0.9f), modifier = Modifier.size(20.dp)) },
                "+${data.xpPerWorkout} XP & a streak day", "When you reach ${data.totalPlannedReps} reps"
            )
            Divider()
            DetailRow(
                { Image(painterResource(R.drawable.stone_blocks_sparkle), null, Modifier.size(24.dp)) },
                if (data.isAllComplete) "Bonus reps" else "${data.repsToGo} reps to finish ${data.stageName}", "Every valid rep builds your tower"
            )
            Divider()
            DetailRow(
                { Icon(Icons.Filled.PhoneAndroid, null, tint = Pc.ivory.copy(alpha = 0.9f), modifier = Modifier.size(20.dp)) },
                "Prop the phone up",
                if (exercise == Exercise.SitUps) "Prop it up to your side so the camera sees your whole body" else "Lean it against something so the front camera sees your full body"
            )
        }
        AnimatedVisibility(error != null) {
            Row(
                Modifier.fillMaxWidth().background(Pc.amber.copy(alpha = 0.1f), RoundedCornerShape(16.dp))
                    .border(1.dp, Pc.amberSoft.copy(alpha = 0.5f), RoundedCornerShape(16.dp)).padding(14.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Icon(Icons.Filled.WifiOff, null, tint = Pc.amberSoft, modifier = Modifier.size(18.dp))
                Text(error.orEmpty(), style = rounded(14, FontWeight.SemiBold), color = Pc.ivory)
            }
        }
        GoldButton(
            if (starting) "Starting…" else "Start Workout", isLoading = starting,
            icon = { Icon(Icons.Filled.PlayArrow, null, tint = Pc.buttonInk, modifier = Modifier.size(20.dp)) }
        ) {
            if (starting) return@GoldButton
            starting = true
            error = null
            scope.launch {
                try {
                    host.session = appState.workouts.start(exercise, null, dashboard?.rules)
                } catch (e: WorkoutException) {
                    error = e.message
                } catch (e: Exception) {
                    error = WorkoutException.Kind.Server.message
                } finally {
                    starting = false
                }
            }
        }
        Text(
            "Workouts need an internet connection to start. If you lose connection or the app closes mid-workout, your reps are kept on this phone and saved automatically.",
            style = rounded(13, FontWeight.Medium), color = Pc.mist.copy(alpha = 0.8f)
        )
    }
}

@Composable
private fun Divider() {
    Box(Modifier.padding(start = 68.dp).fillMaxWidth().height(1.dp).background(Color.White.copy(alpha = 0.08f)))
}

@Composable
private fun DetailRow(icon: @Composable () -> Unit, title: String, subtitle: String) {
    Row(Modifier.padding(horizontal = 16.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        Box(Modifier.size(48.dp).background(Color.White.copy(alpha = 0.08f), CircleShape), contentAlignment = Alignment.Center) { icon() }
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = rounded(17, FontWeight.Bold), color = Pc.ivory)
            Text(subtitle, style = rounded(13, FontWeight.Medium), color = Pc.mist)
        }
    }
}

@Suppress("unused")
private val keep = listOf(Modifier.width(0.dp), Modifier.height(0.dp))


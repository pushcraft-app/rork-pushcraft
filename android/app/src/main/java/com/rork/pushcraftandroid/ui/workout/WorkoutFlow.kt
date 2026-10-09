package com.rork.pushcraftandroid.ui.workout

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowCircleRight
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.CloudUpload
import androidx.compose.material.icons.filled.Construction
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.rork.pushcraftandroid.R
import com.rork.pushcraftandroid.data.AppState
import com.rork.pushcraftandroid.data.Haptics
import com.rork.pushcraftandroid.data.SoundService
import com.rork.pushcraftandroid.model.ActiveSession
import com.rork.pushcraftandroid.model.HomeData
import com.rork.pushcraftandroid.model.SubmitState
import com.rork.pushcraftandroid.model.WorkoutOutcomeDTO
import com.rork.pushcraftandroid.ui.components.CrossedSwordsIcon
import com.rork.pushcraftandroid.ui.components.FlameIcon
import com.rork.pushcraftandroid.ui.components.GoldButton
import com.rork.pushcraftandroid.ui.components.SectionLabel
import com.rork.pushcraftandroid.ui.components.TowerArt
import com.rork.pushcraftandroid.ui.components.TowerOutlineLayer
import com.rork.pushcraftandroid.ui.components.TowerPartLayer
import com.rork.pushcraftandroid.ui.components.TowerParts
import com.rork.pushcraftandroid.ui.components.battleCard
import com.rork.pushcraftandroid.ui.components.pressScale
import com.rork.pushcraftandroid.ui.theme.Pc
import com.rork.pushcraftandroid.ui.theme.rounded
import com.rork.pushcraftandroid.ui.theme.serif
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

private data class Reveal(val towerId: String, val towerName: String, val stage: Int, val stageName: String, val next: String?, val firstNew: Int)

/** Full-screen container: arena → results → stage reveal. */
@Composable
fun WorkoutFlowScreen(session: ActiveSession, appState: AppState, onClose: () -> Unit) {
    var finished by remember { mutableStateOf<Pair<Int, SubmitState>?>(null) }
    var reveal by remember { mutableStateOf<Reveal?>(null) }
    var showReveal by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    BackHandler(enabled = finished != null) { if (finished?.second != SubmitState.Saving) onClose() }

    val phase = when {
        showReveal && reveal != null -> 2
        finished != null -> 1
        else -> 0
    }
    AnimatedContent(phase, transitionSpec = { fadeIn(tween(300)) togetherWith fadeOut(tween(300)) }, label = "flow") { p ->
        when (p) {
            0 -> ArenaScreen(session, appState) { reps, blocks, reason ->
                if (reps == 0 && !session.isBattle) {
                    appState.workouts.abandon(session.id)
                    onClose()
                } else {
                    finished = reps to SubmitState.Saving
                    scope.launch {
                        val state = appState.workouts.finish(session.id, reps, blocks, reason)
                        finished = reps to state
                        reveal = prepareReveal(state)
                    }
                }
            }
            1 -> finished?.let { (reps, state) ->
                WorkoutResultScreen(
                    session, reps, state,
                    onRetry = {
                        finished = reps to SubmitState.Saving
                        scope.launch { finished = reps to appState.workouts.retry(session.id) }
                    },
                    onDone = { if (reveal != null) showReveal = true else onClose() }
                )
            }
            else -> reveal?.let { StageRevealScreen(it, onClose) }
        }
    }
}

private fun prepareReveal(state: SubmitState): Reveal? {
    val outcome = (state as? SubmitState.Saved)?.outcome ?: return null
    val first = outcome.credits.firstOrNull { it.stageCompleted } ?: return null
    val done = outcome.credits.filter { it.towerId == first.towerId && it.stageCompleted }.sortedBy { it.stageNumber }
    val last = done.lastOrNull() ?: first
    val towerDone = last.stageNumber >= TowerParts.STAGE_COUNT
    val next = if (towerDone) null else outcome.credits.firstOrNull { it.towerId == first.towerId && it.stageNumber == last.stageNumber + 1 }?.stageName
        ?: HomeData.stageNames.getOrNull(last.stageNumber)
    return Reveal(first.towerId, first.towerName, last.stageNumber, last.stageName, next, done.firstOrNull()?.stageNumber ?: last.stageNumber)
}

/** Results after a workout or battle run, showing the server-accepted outcome. */
@Composable
fun WorkoutResultScreen(session: ActiveSession, reps: Int, state: SubmitState, onRetry: () -> Unit, onDone: () -> Unit) {
    var appeared by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { appeared = true }
    LaunchedEffect(state) { if ((state as? SubmitState.Saved)?.outcome?.isCompleted == true) Haptics.success() }
    val a by animateFloatAsState(if (appeared) 1f else 0f, spring(dampingRatio = 0.7f, stiffness = 140f), label = "res")
    val accent = when (state) {
        SubmitState.Saving -> Pc.progressCyan
        is SubmitState.Saved -> if (state.outcome.isCompleted) Pc.progressCyan else Pc.amberSoft
        SubmitState.Queued -> Pc.amberSoft
        is SubmitState.Dropped -> Pc.danger
    }
    val title = when (state) {
        SubmitState.Saving -> "Saving your workout…"
        is SubmitState.Saved -> if (session.isBattle) "Battle run saved" else if (state.outcome.isCompleted) "Workout complete" else "Partial workout"
        SubmitState.Queued -> "Saved on this phone"
        is SubmitState.Dropped -> "Couldn't save"
    }
    val unit = session.exercise.unitName
    val subtitle = when (state) {
        SubmitState.Saving -> "$reps $unit"
        is SubmitState.Saved -> if (state.outcome.isCompleted) "${state.outcome.reps} $unit · target reached"
        else "${state.outcome.reps} $unit · ${state.outcome.completionReps} needed for XP and your streak"
        SubmitState.Queued -> "You're offline. Your $reps reps are safe and will sync automatically when you reconnect. Rewards are added once it syncs."
        is SubmitState.Dropped -> state.message
    }
    Box(
        Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Pc.journeyTop, Pc.night)))
            .background(Brush.radialGradient(listOf(accent.copy(alpha = 0.22f), Color.Transparent), center = Offset(540f, 0f), radius = 1150f))
    ) {
        Column(
            Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(22.dp)
        ) {
            Column(Modifier.padding(top = 36.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(
                    Modifier.size(96.dp).scale(0.6f + 0.4f * a).alpha(a).background(accent.copy(alpha = 0.14f), CircleShape).border(2.dp, accent.copy(alpha = 0.6f), CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    when (state) {
                        SubmitState.Saving -> CircularProgressIndicator(color = accent)
                        is SubmitState.Saved -> Icon(if (state.outcome.isCompleted) Icons.Filled.Verified else Icons.Filled.Construction, null, tint = accent, modifier = Modifier.size(44.dp))
                        SubmitState.Queued -> Icon(Icons.Filled.CloudUpload, null, tint = accent, modifier = Modifier.size(44.dp))
                        is SubmitState.Dropped -> Icon(Icons.Filled.Warning, null, tint = accent, modifier = Modifier.size(44.dp))
                    }
                }
                Text(title, style = serif(32), color = Pc.ivory, textAlign = TextAlign.Center)
                Text(subtitle, style = rounded(15, FontWeight.Medium), color = Pc.mist, textAlign = TextAlign.Center)
            }
            if (state is SubmitState.Saved) {
                Column(Modifier.alpha(a).offset(y = (16 * (1 - a)).dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    RewardGrid(state.outcome)
                    state.outcome.battleSubmission?.let { BattleNote(it, state.outcome.reps) }
                    if (state.outcome.credits.isNotEmpty() || state.outcome.overflowReps > 0) ConstructionCard(state.outcome)
                }
            }
            when (state) {
                SubmitState.Saving -> Unit
                SubmitState.Queued -> Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    GoldButton("Try Again", icon = { Icon(Icons.Filled.Refresh, null, tint = Pc.buttonInk, modifier = Modifier.size(18.dp)) }, onClick = onRetry)
                    Box(Modifier.fillMaxWidth().height(46.dp).pressScale(onClick = onDone), contentAlignment = Alignment.Center) {
                        Text("Done", style = rounded(17, FontWeight.SemiBold), color = Pc.mist)
                    }
                }
                else -> GoldButton("Done", icon = { Icon(Icons.Filled.Check, null, tint = Pc.buttonInk, modifier = Modifier.size(18.dp)) }, onClick = onDone)
            }
        }
    }
}

@Composable
private fun RewardGrid(o: WorkoutOutcomeDTO) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            RewardTile("${o.reps}", "Reps", Pc.progressCyan, Modifier.weight(1f)) { Image(painterResource(R.drawable.stat_dumbbell), null, Modifier.size(28.dp)) }
            RewardTile("+${o.coinsAwarded}", "Coins", Pc.gold, Modifier.weight(1f)) { Image(painterResource(R.drawable.gold_coin_star), null, Modifier.size(26.dp)) }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            RewardTile("+${o.xpAwarded}", "XP", Pc.progressCyan, Modifier.weight(1f)) { Icon(Icons.Filled.AutoAwesome, null, tint = Pc.progressCyan, modifier = Modifier.size(22.dp)) }
            RewardTile(if (o.streakDayAwarded) "+1" else "—", if (o.streakDayAwarded) "Streak day" else "Streak", Pc.streakOrange, Modifier.weight(1f)) { FlameIcon(22.dp) }
        }
    }
}

@Composable
private fun RewardTile(value: String, label: String, color: Color, modifier: Modifier, icon: @Composable () -> Unit) {
    Row(modifier.battleCard().padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.width(30.dp), contentAlignment = Alignment.Center) { icon() }
        Column {
            Text(value, style = rounded(24, FontWeight.ExtraBold), color = color, maxLines = 1)
            Text(label, style = rounded(12, FontWeight.SemiBold), color = Pc.mist)
        }
    }
}

@Composable
private fun BattleNote(submission: String, reps: Int) {
    val scored = submission == "scored"
    Row(Modifier.fillMaxWidth().battleCard().padding(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        CrossedSwordsIcon(if (scored) Pc.amberSoft else Pc.mist, Modifier.size(28.dp))
        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(if (scored) "Battle score: $reps" else "Too late for the battle", style = rounded(17, FontWeight.Bold), color = Pc.ivory)
            Text(
                if (scored) "Your score is in. The result appears once your opponent submits or the deadline passes."
                else "This run reached the server after the battle deadline, so it doesn't change the result. Your progress still counts.",
                style = rounded(13, FontWeight.Medium), color = Pc.mist
            )
        }
    }
}

@Composable
private fun ConstructionCard(o: WorkoutOutcomeDTO) {
    Column(Modifier.fillMaxWidth().battleCard().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SectionLabel("CONSTRUCTION")
        o.credits.forEach { c ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Icon(if (c.stageCompleted) Icons.Filled.CheckCircle else Icons.Filled.Construction, null, tint = if (c.stageCompleted) Pc.success else Pc.amberSoft, modifier = Modifier.size(20.dp))
                Column(Modifier.weight(1f)) {
                    Text("${c.towerName} · Stage ${c.stageNumber}", style = rounded(15, FontWeight.Bold), color = Pc.ivory)
                    Text(if (c.stageCompleted) "${c.stageName} complete" else "${c.stageName} · +${c.reps} reps", style = rounded(13, FontWeight.Medium), color = Pc.mist)
                }
                Text("+${c.reps}", style = rounded(15, FontWeight.ExtraBold), color = Pc.progressCyan)
            }
        }
        if (!o.isCompleted) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Filled.ArrowCircleRight, null, tint = Pc.progressCyan, modifier = Modifier.size(16.dp))
                Text("Progress saved — your next session continues from here.", style = rounded(13, FontWeight.SemiBold), color = Pc.mist)
            }
        }
        o.towersCompleted.forEach { t ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Image(painterResource(R.drawable.stat_tower), null, Modifier.size(26.dp))
                Text("${t.towerName} built!", style = serif(17), color = Pc.gold)
            }
        }
        if (o.overflowReps > 0) {
            Text("Every tower is built. These ${o.overflowReps} reps still count toward your stats, coins and streak.", style = rounded(13, FontWeight.Medium), color = Pc.mist)
        }
    }
}

/** Celebration: finished parts drop in with dust and sparkles, then the next outline. */
@Composable
private fun StageRevealScreen(r: Reveal, onContinue: () -> Unit) {
    val key = TowerArt.key(r.towerId)
    val stage = r.stage.coerceIn(1, TowerParts.STAGE_COUNT)
    val firstNew = r.firstNew.coerceIn(1, stage)
    val newStages = (firstNew..stage).toList()
    val nextStage = if (stage < TowerParts.STAGE_COUNT) stage + 1 else null
    var announced by remember { mutableStateOf(false) }
    val dropped = remember { mutableStateListOf<Int>() }
    var showNext by remember { mutableStateOf(false) }
    val sparkle = remember { Animatable(0f) }
    val shimmer = remember { Animatable(-1f) }
    val sparkles = remember { List(20) { Triple(Random.nextDouble(0.0, 2 * Math.PI), Random.nextDouble(60.0, 175.0), it % 3 != 0) } }

    LaunchedEffect(Unit) {
        delay(150); announced = true
        delay(350)
        newStages.forEachIndexed { i, s ->
            if (i > 0) delay(320)
            dropped.add(s)
            launch {
                delay(200)
                SoundService.play(SoundService.Effect.Drop, maxOf(0.82f - 0.04f * i, 0.68f))
                Haptics.stoneLand()
            }
        }
        delay(220)
        Haptics.success()
        SoundService.play(SoundService.Effect.Coins)
        if (r.next == null) {
            SoundService.play(SoundService.Effect.Shatter, 0.85f)
            Haptics.finale()
        }
        launch { sparkle.animateTo(1f, tween(700)) }
        delay(300)
        launch { shimmer.animateTo(1.6f, tween(1000)) }
        delay(800)
        showNext = true
    }
    val ann by animateFloatAsState(if (announced) 1f else 0f, spring(dampingRatio = 0.8f, stiffness = 160f), label = "ann")
    val nextA by animateFloatAsState(if (showNext) 1f else 0f, tween(600), label = "next")

    Box(
        Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Pc.journeyTop, Pc.night)))
            .background(Brush.radialGradient(listOf(Pc.gold.copy(alpha = 0.16f), Color.Transparent), radius = 1000f))
    ) {
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding(), horizontalAlignment = Alignment.CenterHorizontally) {
            Column(
                Modifier.padding(top = 44.dp).padding(horizontal = 20.dp).alpha(ann).offset(y = (18 * (1 - ann)).dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text("STAGE $stage COMPLETE", style = rounded(12, FontWeight.Bold, 3f), color = Pc.amberSoft)
                Text(r.stageName, style = serif(36), color = Pc.ivory, textAlign = TextAlign.Center)
                Text(r.towerName, style = rounded(15, FontWeight.Medium), color = Pc.mist)
            }
            Box(Modifier.padding(top = 14.dp).height(380.dp).width(253.dp), contentAlignment = Alignment.Center) {
                if (key != null) {
                    for (s in 1 until firstNew) TowerPartLayer(key, s)
                    if (nextStage != null) TowerOutlineLayer(key, nextStage, modifier = Modifier.alpha(nextA))
                    newStages.forEach { s ->
                        val isDropped = s in dropped
                        val dy by animateFloatAsState(if (isDropped) 0f else -209f, spring(dampingRatio = 0.52f, stiffness = 160f), label = "d$s")
                        TowerPartLayer(
                            key, s,
                            Modifier.graphicsLayer { translationY = dy * density; alpha = if (isDropped) 1f else 0f }
                                .drawWithContent {
                                    drawContent()
                                    val x = shimmer.value * size.width
                                    drawRect(
                                        Brush.linearGradient(
                                            listOf(Color.Transparent, Pc.gold.copy(alpha = 0.6f), Color.White.copy(alpha = 0.75f), Pc.gold.copy(alpha = 0.6f), Color.Transparent),
                                            start = Offset(x, 0f), end = Offset(x + size.width * 0.45f, size.height * 0.15f)
                                        ),
                                        blendMode = androidx.compose.ui.graphics.BlendMode.SrcAtop
                                    )
                                }
                        )
                    }
                }
                Canvas(Modifier.fillMaxSize()) {
                    if (sparkle.value <= 0f) return@Canvas
                    val c = Offset(size.width / 2, size.height * 0.58f)
                    val e = 1 - (1 - sparkle.value) * (1 - sparkle.value) * (1 - sparkle.value)
                    sparkles.forEach { (ang, dist, gold) ->
                        val p = c + Offset((cos(ang) * dist * e * density / 2.5).toFloat(), (sin(ang) * dist * e * density / 2.5).toFloat())
                        drawCircle(if (gold) Pc.gold else Color.White, 4.dp.toPx() * e, p, alpha = 0.85f)
                    }
                }
            }
            Text(
                if (r.next != null) "Next up: ${r.next}" else "${r.towerName} is complete!",
                style = rounded(16, FontWeight.SemiBold), color = if (r.next != null) Pc.mist else Pc.gold,
                modifier = Modifier.padding(top = 18.dp).alpha(nextA)
            )
            Spacer(Modifier.weight(1f))
            GoldButton("Continue", Modifier.padding(horizontal = 20.dp).padding(bottom = 26.dp), icon = {
                Icon(Icons.Filled.Check, null, tint = Pc.buttonInk, modifier = Modifier.size(18.dp))
            }, onClick = onContinue)
        }
    }
}

@Suppress("unused")
private val keep: List<ImageVector> = emptyList()

@Suppress("unused")
private val keepMod = Modifier.heightIn(0.dp)

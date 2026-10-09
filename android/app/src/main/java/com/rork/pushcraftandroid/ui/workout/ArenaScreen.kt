package com.rork.pushcraftandroid.ui.workout

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.view.WindowManager
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.GppMaybe
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.TrackChanges
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.VideocamOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.rork.pushcraftandroid.R
import com.rork.pushcraftandroid.data.AppPreferences
import com.rork.pushcraftandroid.data.AppState
import com.rork.pushcraftandroid.data.BattleLiveSync
import com.rork.pushcraftandroid.data.Haptics
import com.rork.pushcraftandroid.data.SoundService
import com.rork.pushcraftandroid.game.BlockPhase
import com.rork.pushcraftandroid.game.BlockView
import com.rork.pushcraftandroid.game.CameraStatus
import com.rork.pushcraftandroid.game.CueView
import com.rork.pushcraftandroid.game.DepthMeter
import com.rork.pushcraftandroid.game.EffectsOverlay
import com.rork.pushcraftandroid.game.GameEngine
import com.rork.pushcraftandroid.game.HealthPips
import com.rork.pushcraftandroid.game.PayoutText
import com.rork.pushcraftandroid.game.PoseCameraView
import com.rork.pushcraftandroid.game.RepPhase
import com.rork.pushcraftandroid.game.SkeletonView
import com.rork.pushcraftandroid.game.StatCard
import com.rork.pushcraftandroid.model.ActiveSession
import com.rork.pushcraftandroid.model.WorkoutEndReason
import com.rork.pushcraftandroid.ui.components.BattleAvatar
import com.rork.pushcraftandroid.ui.components.pressScale
import com.rork.pushcraftandroid.ui.theme.Pc
import com.rork.pushcraftandroid.ui.theme.rounded
import com.rork.pushcraftandroid.ui.theme.serif
import kotlinx.coroutines.delay
import java.time.Duration
import java.time.Instant

/** Keeps the screen awake while a workout runs. */
@Composable
fun KeepScreenOn() {
    val view = LocalView.current
    DisposableEffect(Unit) {
        view.keepScreenOn = true
        onDispose { view.keepScreenOn = false }
    }
}

/** Camera feed, skeleton, effects and the gradient scrims shared by arena screens. */
@Composable
fun ArenaBackdrop(engine: GameEngine, hud: @Composable () -> Unit) {
    Box(Modifier.fillMaxSize().background(Color.Black)) {
        PoseCameraView(engine, Modifier.fillMaxSize())
        Box(
            Modifier.fillMaxSize().background(
                Brush.verticalGradient(
                    0f to Color.Black.copy(alpha = 0.55f), 0.3f to Color.Transparent,
                    0.62f to Color.Transparent, 1f to Color.Black.copy(alpha = 0.65f)
                )
            )
        )
        SkeletonView(engine.pose, Modifier.fillMaxSize().onGloballyPositioned { engine.screenSize = Size(it.size.width.toFloat(), it.size.height.toFloat()) })
        hud()
        EffectsOverlay(engine, Modifier.fillMaxSize())
    }
}

/** Block, health pips and tier line. Reports its frame to the engine. */
@Composable
fun BlockStage(engine: GameEngine, side: Float, showLabel: Boolean = true) {
    val charging = engine.tracking.phase == RepPhase.Charging || engine.tracking.phase == RepPhase.Charged
    val damage = if (engine.spec.health > 0) engine.hitsTaken.toDouble() / engine.spec.health else 0.0
    val dropOffset by animateFloatAsState(if (engine.blockPhase == BlockPhase.Dropping) -260f else 0f, androidx.compose.animation.core.spring(dampingRatio = 0.55f, stiffness = 220f), label = "drop")
    val shatterScale by animateFloatAsState(if (engine.blockPhase == BlockPhase.Shattered) 1.35f else 1f, tween(140), label = "sh")
    val shatterAlpha by animateFloatAsState(if (engine.blockPhase == BlockPhase.Shattered || engine.blockPhase == BlockPhase.Dropping && dropOffset < -200f) 0f else 1f, tween(140), label = "sa")
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Box(
            Modifier.size((side - 22).dp).onGloballyPositioned { engine.blockFrame = it.boundsInRoot() },
            contentAlignment = Alignment.Center
        ) {
            androidx.compose.runtime.key(engine.blockId) {
                BlockView(
                    tier = engine.spec.tier, seed = engine.blockSeed, damage = damage,
                    charge = if (charging) engine.tracking.depth else 0.0,
                    isCharged = engine.tracking.phase == RepPhase.Charged,
                    hitTrigger = engine.hitCount, side = side - 22,
                    modifier = Modifier
                        .graphicsLayerCompat(dropOffset, shatterScale, shatterAlpha)
                )
            }
            androidx.compose.animation.AnimatedVisibility(engine.payout != null, enter = scaleIn(initialScale = 0.3f) + fadeIn(), exit = fadeOut()) {
                engine.payout?.let { PayoutText(it.amount) }
            }
        }
        HealthPips(engine.spec.health, engine.health, Modifier.alpha(if (engine.blockPhase == BlockPhase.Shattered) 0f else 1f))
        if (showLabel) {
            Text(
                "${engine.spec.tier.label}  ·  LV ${engine.spec.level + 1}  ·  +${engine.spec.payout}",
                style = rounded(12, FontWeight.ExtraBold, 1.6f), color = engine.spec.tier.accent
            )
        }
    }
}

private fun Modifier.graphicsLayerCompat(dy: Float, scale: Float, alpha: Float) = this.graphicsLayer {
    translationY = dy * density
    scaleX = scale
    scaleY = scale
    this.alpha = alpha
}

/** Error card for camera denied / missing / failed. */
@Composable
fun CameraMessageCard(status: CameraStatus) {
    val context = LocalContext.current
    val (title, body) = when (status) {
        CameraStatus.Denied -> "Camera access needed" to "Your reps control the game through the camera. Allow camera access in Settings to start smashing."
        CameraStatus.NoCamera -> "No camera found" to "This device doesn't have a camera available right now."
        CameraStatus.Failed -> "Camera couldn't start" to "Something went wrong starting the camera. Close and reopen the app to try again."
        else -> return
    }
    Box(Modifier.fillMaxSize().padding(28.dp), contentAlignment = Alignment.Center) {
        Column(
            Modifier
                .background(Color(0xE6101A2E), RoundedCornerShape(28.dp))
                .border(1.5.dp, Pc.cyan.copy(alpha = 0.6f), RoundedCornerShape(28.dp))
                .padding(28.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Icon(if (status == CameraStatus.Failed) Icons.Filled.GppMaybe else Icons.Filled.VideocamOff, null, tint = Pc.cyan, modifier = Modifier.size(40.dp))
            Text(title, style = rounded(22, FontWeight.ExtraBold), color = Color.White)
            Text(body, style = rounded(15, FontWeight.Medium), color = Color.White.copy(alpha = 0.75f), textAlign = TextAlign.Center)
            if (status == CameraStatus.Denied) {
                Box(
                    Modifier.heightIn(min = 48.dp).background(Pc.cyan, CircleShape).pressScale {
                        context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null)))
                    }.padding(horizontal = 24.dp, vertical = 14.dp)
                ) { Text("Open Settings", style = rounded(16, FontWeight.Bold), color = Color.Black) }
            }
        }
    }
}

/**
 * Live workout: camera + skeleton, floating block, counters and depth meter.
 * Checkpoints every rep; regular workouts get a 5-4-3-2-1 countdown, battles
 * score for exactly the battle duration from the registered start.
 */
@Composable
fun ArenaScreen(session: ActiveSession, appState: AppState, onEnd: (reps: Int, blocks: Int, reason: WorkoutEndReason) -> Unit) {
    KeepScreenOn()
    val engine = remember { GameEngine(session.exercise) }
    val live = remember { BattleLiveSync() }
    val opponentReps by live.opponentReps.collectAsState()
    var hasEnded by remember { mutableStateOf(false) }
    var confirmEnd by remember { mutableStateOf(false) }
    var countdown by remember { mutableStateOf<Int?>(null) }
    var showGo by remember { mutableStateOf(false) }
    var remaining by remember { mutableIntStateOf(session.battleDurationSeconds) }
    var showTip by remember { mutableStateOf(false) }
    val isComplete = engine.reps >= session.completionReps
    val battles by appState.battles.battles.collectAsState()
    val battle = session.battleId?.let { id -> battles.firstOrNull { it.id == id } }
    val dashboard by appState.progress.dashboard.collectAsState()

    fun end(reason: WorkoutEndReason) {
        if (hasEnded) return
        if (!session.isBattle) AppPreferences.hasSeenProgressTip = true
        engine.isAcceptingReps = false
        appState.workouts.checkpoint(session.id, engine.reps, engine.smashCount)
        hasEnded = true
        onEnd(engine.reps, engine.smashCount, reason)
    }

    DisposableEffect(Unit) {
        engine.onRep = {
            appState.workouts.checkpoint(session.id, engine.reps, engine.smashCount)
            live.send(engine.reps)
        }
        session.battleId?.let { live.connect(it) }
        engine.isAcceptingReps = session.isBattle
        engine.start()
        onDispose {
            if (!hasEnded) appState.workouts.checkpoint(session.id, engine.reps, engine.smashCount)
            live.disconnect()
            engine.dispose()
        }
    }
    LaunchedEffect(Unit) {
        if (!session.isBattle && !AppPreferences.hasSeenProgressTip) {
            delay(800); showTip = true; delay(7000); showTip = false
            AppPreferences.hasSeenProgressTip = true
        }
    }
    LaunchedEffect(Unit) {
        if (session.isBattle) return@LaunchedEffect
        delay(600)
        for (tick in 5 downTo 1) {
            if (hasEnded) return@LaunchedEffect
            countdown = tick
            SoundService.play(SoundService.Effect.Drop, 1.5f, 0.8f)
            Haptics.tick()
            delay(1000)
        }
        if (hasEnded) return@LaunchedEffect
        countdown = null
        engine.isAcceptingReps = true
        showGo = true
        SoundService.play(SoundService.Effect.Hit, 1.25f)
        Haptics.success()
        delay(800)
        showGo = false
    }
    LaunchedEffect(Unit) {
        while (!hasEnded) {
            delay(4000)
            if (!hasEnded) {
                appState.workouts.checkpoint(session.id, engine.reps, engine.smashCount)
                live.send(engine.reps)
            }
        }
    }
    LaunchedEffect(Unit) {
        if (!session.isBattle) return@LaunchedEffect
        while (!hasEnded) {
            val elapsed = Duration.between(session.startedAt, Instant.now()).toMillis() / 1000.0
            val left = maxOf(0.0, session.battleDurationSeconds - elapsed)
            remaining = Math.ceil(left).toInt()
            if (left <= 0) {
                engine.isAcceptingReps = false
                end(WorkoutEndReason.Timer)
                return@LaunchedEffect
            }
            delay(250)
        }
    }
    LaunchedEffect(isComplete) { if (isComplete && !session.isBattle) Haptics.smash() }

    BackHandler {
        if (session.isBattle) confirmEnd = true
        else if (engine.reps == 0) end(WorkoutEndReason.Finished) else confirmEnd = true
    }

    ArenaBackdrop(engine) {
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                if (!session.isBattle) {
                    Row(
                        Modifier.height(40.dp).background(Pc.panel, CircleShape).border(1.dp, Color.White.copy(alpha = 0.22f), CircleShape)
                            .pressScale { if (engine.reps == 0) end(WorkoutEndReason.Finished) else confirmEnd = true }
                            .padding(horizontal = 14.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Icon(Icons.Filled.Close, null, tint = Color.White, modifier = Modifier.size(16.dp))
                        Text("Done", style = rounded(14, FontWeight.Bold), color = Color.White)
                    }
                }
                Spacer(Modifier.weight(1f))
                if (session.isBattle) BattleTimer(remaining) else TargetPill(engine.reps, session.completionReps, isComplete)
            }
            AnimatedVisibility(showTip, enter = slideInVertically() + fadeIn(), exit = fadeOut(), modifier = Modifier.align(Alignment.CenterHorizontally)) {
                Row(
                    Modifier.padding(top = 8.dp).background(Pc.panel, CircleShape).border(1.dp, Pc.progressCyan.copy(alpha = 0.45f), CircleShape).padding(horizontal = 14.dp, vertical = 9.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(Icons.Filled.Verified, null, tint = Pc.progressCyan, modifier = Modifier.size(15.dp))
                    Text("Every rep saves as you go — stop anytime.", style = rounded(13, FontWeight.SemiBold), color = Color.White.copy(alpha = 0.92f))
                }
            }
            if (session.isBattle) {
                VersusHeader(
                    myReps = engine.reps, opponentReps = opponentReps,
                    myName = dashboard?.profile?.displayName.orEmpty(), myAvatar = dashboard?.profile?.avatarPath,
                    opponentName = battle?.opponentName, opponentAvatar = battle?.opponentAvatarPath,
                    modifier = Modifier.padding(horizontal = 16.dp).padding(top = 10.dp)
                )
            } else {
                Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 10.dp)) {
                    StatCard(engine.reps, "REPS", Pc.cyan) { Icon(Icons.Filled.FitnessCenter, null, tint = Pc.cyan, modifier = Modifier.size(21.dp)) }
                    Spacer(Modifier.weight(1f))
                    StatCard(engine.displayedCoins, "COINS", Pc.gold) {
                        Image(
                            painterResource(R.drawable.gold_coin_star), null,
                            Modifier.size(26.dp).onGloballyPositioned { engine.coinTarget = it.boundsInRoot().center }
                        )
                    }
                }
            }
            Box(Modifier.fillMaxWidth().padding(top = 14.dp), contentAlignment = Alignment.Center) { BlockStage(engine, 150f) }
            Spacer(Modifier.weight(1f))
            Column(Modifier.padding(bottom = 10.dp), verticalArrangement = Arrangement.spacedBy(6.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                DepthMeter(engine.tracking, Modifier.padding(horizontal = 40.dp))
                CueView(engine.cue, engine.exercise)
            }
        }
        if (countdown != null || showGo) CountdownOverlay(countdown, showGo)
        CameraMessageCard(engine.cameraStatus)
    }

    if (confirmEnd) {
        val title = if (session.isBattle) "End your battle run?" else if (engine.reps == 0) "Leave this workout?" else "End workout?"
        val message = when {
            session.isBattle -> "You only get one run. Your score will be ${engine.reps} ${session.exercise.unitName}."
            engine.reps == 0 -> "No reps yet, so nothing will be saved."
            isComplete -> "Your ${engine.reps} reps will be saved to your tower."
            else -> "Your ${engine.reps} reps are already saved — your tower keeps every one, and your next session continues from there. Reach ${session.completionReps} for XP and a streak day."
        }
        AlertDialog(
            onDismissRequest = { confirmEnd = false },
            containerColor = Pc.towersNavy,
            title = { Text(title, style = rounded(19, FontWeight.Bold), color = Pc.ivory) },
            text = { Text(message, style = rounded(15, FontWeight.Medium), color = Pc.mist) },
            confirmButton = {
                TextButton({ confirmEnd = false; end(WorkoutEndReason.Finished) }) {
                    Text(if (engine.reps == 0 && !session.isBattle) "Leave Workout" else "End & Save", color = Pc.danger, style = rounded(15, FontWeight.Bold))
                }
            },
            dismissButton = { TextButton({ confirmEnd = false }) { Text("Keep Going", color = Pc.amberSoft, style = rounded(15, FontWeight.Bold)) } }
        )
    }
}

@Composable
private fun TargetPill(reps: Int, target: Int, complete: Boolean) {
    val bg = if (complete) Brush.verticalGradient(listOf(Color(0xFF7BE9FF), Pc.progressCyan)) else Brush.verticalGradient(listOf(Pc.panel, Pc.panel))
    Row(
        Modifier.height(40.dp)
            .shadow(if (complete) 10.dp else 0.dp, CircleShape, ambientColor = Pc.progressCyan, spotColor = Pc.progressCyan)
            .background(bg, CircleShape)
            .border(1.dp, Color.White.copy(alpha = if (complete) 0f else 0.22f), CircleShape)
            .padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)
    ) {
        val color = if (complete) Color(0xFF062330) else Color.White
        Icon(if (complete) Icons.Filled.Verified else Icons.Filled.TrackChanges, null, tint = color, modifier = Modifier.size(15.dp))
        Text(if (complete) "COMPLETED · KEEP GOING" else "$reps / $target", style = rounded(14, FontWeight.ExtraBold, if (complete) 1f else 0f), color = color)
    }
}

@Composable
private fun BattleTimer(remaining: Int) {
    val low = remaining <= 10
    val colors = if (low) listOf(Color(0xFFFF8A8A), Color(0xFFE04848)) else listOf(Pc.amberSoft, Pc.amberDeep)
    Row(
        Modifier.height(40.dp).shadow(10.dp, CircleShape, ambientColor = colors[1], spotColor = colors[1])
            .background(Brush.verticalGradient(colors), CircleShape).padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)
    ) {
        val ink = if (low) Color(0xFF3A0A0A) else Pc.buttonInk
        Icon(Icons.Filled.Timer, null, tint = ink, modifier = Modifier.size(16.dp))
        Text("%d:%02d".format(remaining / 60, remaining % 60), style = rounded(17, FontWeight.ExtraBold), color = ink)
    }
}

/** Battle header: both players with live reps and a tug-of-war gauge. */
@Composable
private fun VersusHeader(myReps: Int, opponentReps: Int, myName: String, myAvatar: String?, opponentName: String?, opponentAvatar: String?, modifier: Modifier = Modifier) {
    val myColor = Pc.cyan
    val oppColor = Color(0xFFFF5A5A)
    val total = myReps + opponentReps
    val share by animateFloatAsState(if (total == 0) 0.5f else myReps.toFloat() / total, label = "share")
    Column(
        modifier.fillMaxWidth().shadow(10.dp, RoundedCornerShape(22.dp)).background(Pc.panel, RoundedCornerShape(22.dp))
            .border(1.dp, Color.White.copy(alpha = 0.14f), RoundedCornerShape(22.dp)).padding(horizontal = 14.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            BattleAvatar(myName, myAvatar, 44.dp, Modifier.border(2.5.dp, myColor, CircleShape))
            Spacer(Modifier.width(8.dp))
            Text("$myReps", style = rounded(24, FontWeight.Black), color = Color.White)
            Spacer(Modifier.weight(1f))
            Text("VS", style = rounded(14, FontWeight.Black, 1.5f), color = Color.White.copy(alpha = 0.55f))
            Spacer(Modifier.weight(1f))
            Text("$opponentReps", style = rounded(24, FontWeight.Black), color = Color.White)
            Spacer(Modifier.width(8.dp))
            BattleAvatar(opponentName ?: "Waiting…", opponentAvatar, 44.dp, Modifier.border(2.5.dp, oppColor, CircleShape))
        }
        BoxWithConstraints(Modifier.fillMaxWidth().height(12.dp).background(Brush.horizontalGradient(listOf(oppColor, oppColor.copy(alpha = 0.7f))), CircleShape).border(1.dp, Color.White.copy(alpha = 0.25f), CircleShape)) {
            Box(Modifier.height(12.dp).width(maxOf(maxWidth * share, 12.dp)).background(Brush.horizontalGradient(listOf(myColor.copy(alpha = 0.7f), myColor)), CircleShape))
        }
    }
}

@Composable
private fun CountdownOverlay(count: Int?, isGo: Boolean) {
    Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.42f)), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
            AnimatedContent(if (isGo) -1 else (count ?: 0), transitionSpec = { (scaleIn(initialScale = 1.7f) + fadeIn()) togetherWith fadeOut() }, label = "cd") { v ->
                if (v == -1) {
                    Text("GO!", style = rounded(96, FontWeight.Black).copy(brush = Brush.verticalGradient(listOf(Color.White, Pc.progressCyan))))
                } else {
                    Text("$v", style = rounded(110, FontWeight.Black), color = Color.White)
                }
            }
            if (!isGo) Text("GET INTO POSITION", style = rounded(17, FontWeight.Bold, 2f), color = Color.White.copy(alpha = 0.9f))
        }
    }
}

/** Onboarding intro: one crate that breaks after 4 push-ups (not saved). */
@Composable
fun IntroWorkoutScreen(onFinish: (Int) -> Unit, onSkip: () -> Unit) {
    KeepScreenOn()
    val target = com.rork.pushcraftandroid.data.OnboardingModel.INTRO_REPS
    val engine = remember { GameEngine(com.rork.pushcraftandroid.model.Exercise.PushUps, firstBlockHealth = target) }
    var celebrating by remember { mutableStateOf(false) }
    var finished by remember { mutableStateOf(false) }
    DisposableEffect(Unit) {
        engine.start()
        onDispose { engine.dispose() }
    }
    LaunchedEffect(engine.smashCount) {
        if (engine.smashCount >= 1 && !celebrating) {
            engine.isAcceptingReps = false
            delay(900)
            Haptics.success()
            celebrating = true
        }
    }
    ArenaBackdrop(engine) {
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().alpha(if (celebrating) 0f else 1f)) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(
                    Modifier.height(40.dp).background(Pc.panel, CircleShape).border(1.dp, Color.White.copy(alpha = 0.22f), CircleShape)
                        .pressScale { finished = true; onSkip() }.padding(horizontal = 16.dp),
                    contentAlignment = Alignment.Center
                ) { Text("Skip", style = rounded(15, FontWeight.Bold), color = Color.White) }
                Spacer(Modifier.weight(1f))
                Row(
                    Modifier.height(40.dp).background(Pc.panel, CircleShape).border(1.5.dp, Pc.amberSoft.copy(alpha = 0.7f), CircleShape)
                        .onGloballyPositioned { engine.coinTarget = it.boundsInRoot().center }.padding(horizontal = 14.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)
                ) {
                    Icon(Icons.Filled.TrackChanges, null, tint = Color.White, modifier = Modifier.size(15.dp))
                    Text("${minOf(engine.reps, target)} / $target", style = rounded(16, FontWeight.ExtraBold), color = Color.White)
                }
            }
            Text(
                "Smash the crate with $target push-ups", style = serif(20), color = Pc.ivory,
                modifier = Modifier.align(Alignment.CenterHorizontally).padding(top = 16.dp)
            )
            Box(Modifier.fillMaxWidth().padding(top = 18.dp), contentAlignment = Alignment.Center) { BlockStage(engine, 172f, showLabel = false) }
            Spacer(Modifier.weight(1f))
            Column(Modifier.padding(bottom = 20.dp), verticalArrangement = Arrangement.spacedBy(10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                DepthMeter(engine.tracking, Modifier.padding(horizontal = 40.dp))
                CueView(engine.cue, engine.exercise)
            }
        }
        if (celebrating) {
            IntroCelebration(engine.reps) {
                if (!finished) { finished = true; onFinish(engine.reps) }
            }
        }
        if (engine.cameraStatus == CameraStatus.Denied || engine.cameraStatus == CameraStatus.NoCamera || engine.cameraStatus == CameraStatus.Failed) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(
                    Modifier.padding(24.dp).background(Pc.obNavy, RoundedCornerShape(28.dp)).border(1.dp, Pc.obCardBorder, RoundedCornerShape(28.dp)).padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    Icon(Icons.Filled.VideocamOff, null, tint = Pc.amberSoft, modifier = Modifier.size(36.dp))
                    Text(
                        if (engine.cameraStatus == CameraStatus.Denied) "Camera access needed" else "Camera unavailable",
                        style = serif(22), color = Pc.ivory
                    )
                    Text("Pushcraft counts your push-ups with the camera. Video never leaves your phone.", style = rounded(15, FontWeight.Medium), color = Pc.mist, textAlign = TextAlign.Center)
                    com.rork.pushcraftandroid.ui.onboarding.OnboardingSecondaryButton("Skip for now") { finished = true; onSkip() }
                }
            }
        }
    }
}

@Composable
private fun IntroCelebration(reps: Int, onContinue: () -> Unit) {
    var burst by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { burst = true }
    val b by animateFloatAsState(if (burst) 1f else 0f, androidx.compose.animation.core.spring(dampingRatio = 0.55f, stiffness = 120f), label = "burst")
    Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.55f)), contentAlignment = Alignment.Center) {
        androidx.compose.foundation.Canvas(Modifier.fillMaxSize()) {
            val c = Offset(size.width / 2, size.height / 2 - 60.dp.toPx())
            for (i in 0 until 14) {
                val a = i / 14.0 * 2 * Math.PI
                val p = c + Offset((Math.cos(a) * 150.dp.toPx() * b).toFloat(), (Math.sin(a) * 150.dp.toPx() * b).toFloat())
                drawCircle(if (i % 2 == 0) Pc.gold else Pc.amberSoft, (if (i % 2 == 0) 6 else 4).dp.toPx(), p, alpha = (1 - b).coerceIn(0f, 1f))
            }
        }
        Column(Modifier.padding(horizontal = 24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp)) {
            Text("CRATE SMASHED!", style = rounded(34, FontWeight.Black).copy(brush = Brush.verticalGradient(listOf(Color.White, Pc.gold))), modifier = Modifier.scale(0.6f + 0.4f * b))
            Text(if (reps == 1) "1 push-up" else "$reps push-ups", style = rounded(20, FontWeight.Bold), color = Pc.ivory)
            com.rork.pushcraftandroid.ui.onboarding.OnboardingPrimaryButton("Continue", modifier = Modifier.padding(top = 12.dp).width(320.dp), onClick = onContinue)
        }
    }
}

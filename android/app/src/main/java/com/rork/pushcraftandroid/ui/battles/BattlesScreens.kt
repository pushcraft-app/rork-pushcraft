package com.rork.pushcraftandroid.ui.battles

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Code
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.DragHandle
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.HourglassEmpty
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Share
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
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import com.rork.pushcraftandroid.data.AppState
import com.rork.pushcraftandroid.data.Haptics
import com.rork.pushcraftandroid.data.PendingSession
import com.rork.pushcraftandroid.data.Progress
import com.rork.pushcraftandroid.data.active
import com.rork.pushcraftandroid.data.completed
import com.rork.pushcraftandroid.data.invitation
import com.rork.pushcraftandroid.model.Battle
import com.rork.pushcraftandroid.model.BattleOutcome
import com.rork.pushcraftandroid.model.BattlePhase
import com.rork.pushcraftandroid.model.Exercise
import com.rork.pushcraftandroid.ui.components.AmberGradient
import com.rork.pushcraftandroid.ui.components.BackTextButton
import com.rork.pushcraftandroid.ui.components.BattleAvatar
import com.rork.pushcraftandroid.ui.components.CountersRow
import com.rork.pushcraftandroid.ui.components.CrossedSwordsIcon
import com.rork.pushcraftandroid.ui.components.GoldButton
import com.rork.pushcraftandroid.ui.components.SectionLabel
import com.rork.pushcraftandroid.ui.components.battleCard
import com.rork.pushcraftandroid.ui.components.pressScale
import com.rork.pushcraftandroid.ui.components.recessed
import com.rork.pushcraftandroid.ui.main.WorkoutHost
import com.rork.pushcraftandroid.ui.theme.Pc
import com.rork.pushcraftandroid.ui.theme.rounded
import com.rork.pushcraftandroid.ui.theme.serif
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

val BattleOutcome.color: Color
    get() = when (this) {
        BattleOutcome.Victory -> Pc.success
        BattleOutcome.Defeat -> Pc.danger
        else -> Pc.mist
    }

fun relativeLeft(deadline: Instant): String {
    val d = Duration.between(Instant.now(), deadline)
    if (d.isNegative) return "0 min"
    val h = d.toHours()
    val m = d.toMinutes() % 60
    return if (h > 0) "$h hr $m min" else "$m min"
}

private val dateFormat = DateTimeFormatter.ofPattern("MMM d, yyyy")
fun formatDate(i: Instant): String = i.atZone(ZoneId.systemDefault()).format(dateFormat)

fun shareBattle(context: Context, battle: Battle) {
    val text = "Challenge me on Pushcraft — ${battle.exercise.challengeTitle}! Enter my battle code: ${battle.code}."
    context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text), "Share battle code"))
}

private enum class Segment(val title: String) { Join("Join"), Active("Active"), Completed("Completed") }

/** Battles tab: create/join via codes, active battles, finished results. */
@Composable
fun BattlesScreen(appState: AppState, nav: NavController, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val battles by appState.battles.battles.collectAsState()
    val hasLoaded by appState.battles.hasLoaded.collectAsState()
    val dashboard by appState.progress.dashboard.collectAsState()
    val home = Progress.homeData(dashboard)
    var segment by remember { mutableStateOf(Segment.Join) }
    var code by remember { mutableStateOf("") }
    var joining by remember { mutableStateOf(false) }
    var creating by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var exercise by remember { mutableStateOf(Exercise.PushUps) }
    var copied by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val invitation = battles.invitation

    LaunchedEffect(Unit) {
        if (!hasLoaded) runCatching { appState.battles.load() }
        appState.battles.battles.value.invitation?.let { exercise = it.exercise }
    }
    LaunchedEffect(copied) { if (copied) { delay(1800); copied = false } }

    Box(modifier.fillMaxSize().background(Pc.towersNavy)) {
        Column(Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(top = 8.dp, bottom = 28.dp)) {
            CountersRow(home.streak, home.xp, home.coinsDisplay)
            Text("Battles", style = serif(34), color = Pc.ivory, modifier = Modifier.padding(top = 20.dp))
            Text("Challenge a friend. Share a code and battle together.", style = rounded(16, FontWeight.Medium), color = Pc.mist, modifier = Modifier.padding(top = 6.dp))

            Row(
                Modifier.padding(top = 18.dp).fillMaxWidth().background(Color(0xFF101D35), RoundedCornerShape(24.dp)).border(1.dp, Color(0xFF27395C), RoundedCornerShape(24.dp)),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Segment.entries.forEachIndexed { i, seg ->
                    if (i > 0) Box(Modifier.width(1.dp).height(22.dp).background(Color.White.copy(alpha = 0.12f)))
                    val sel = segment == seg
                    Box(
                        Modifier.weight(1f).height(46.dp)
                            .then(if (sel) Modifier.shadow(8.dp, CircleShape, ambientColor = Pc.amberDeep, spotColor = Pc.amberDeep).background(AmberGradient, CircleShape) else Modifier)
                            .pressScale { segment = seg },
                        contentAlignment = Alignment.Center
                    ) { Text(seg.title, style = rounded(17, if (sel) FontWeight.Bold else FontWeight.SemiBold), color = if (sel) Pc.buttonInk else Pc.mist) }
                }
            }

            when (segment) {
                Segment.Join -> Column(Modifier.padding(top = 16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Column(Modifier.fillMaxWidth().battleCard().padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                            CrossedSwordsIcon(Pc.iconBlue, Modifier.size(34.dp))
                            Column {
                                Text("Create Battle", style = serif(23), color = Pc.ivory)
                                Text("Create a challenge and invite a friend.", style = rounded(14, FontWeight.Medium), color = Pc.mist)
                            }
                        }
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            SectionLabel("EXERCISE")
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Exercise.entries.forEach { opt ->
                                    val sel = exercise == opt
                                    val shape = RoundedCornerShape(12.dp)
                                    Box(
                                        Modifier.weight(1f).height(40.dp)
                                            .background(if (sel) AmberGradient else SolidColor(Color.White.copy(alpha = 0.06f)), shape)
                                            .border(1.dp, Color.White.copy(alpha = if (sel) 0f else 0.14f), shape)
                                            .pressScale { exercise = opt },
                                        contentAlignment = Alignment.Center
                                    ) { Text(opt.displayName, style = rounded(14, FontWeight.Bold), color = if (sel) Pc.buttonInk else Pc.mist) }
                                }
                            }
                        }
                        if (invitation != null) {
                            Row(Modifier.fillMaxWidth().height(54.dp).recessed().padding(start = 14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                SectionLabel("BATTLE CODE")
                                Box(Modifier.width(1.dp).height(22.dp).background(Color.White.copy(alpha = 0.14f)))
                                Text(invitation.code, style = rounded(22, FontWeight.Bold, 1.5f), color = Pc.ivory, modifier = Modifier.weight(1f))
                                Box(
                                    Modifier.size(44.dp).pressScale {
                                        (context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText("Battle code", invitation.code))
                                        Haptics.tap(); copied = true
                                    },
                                    contentAlignment = Alignment.Center
                                ) { Icon(Icons.Filled.ContentCopy, "Copy battle code", tint = Pc.iconBlue, modifier = Modifier.size(18.dp)) }
                            }
                        }
                        GoldButton(
                            if (invitation == null) "Create & Share Code" else "Share Code", isLoading = creating,
                            icon = { Icon(Icons.Filled.Share, null, tint = Pc.buttonInk, modifier = Modifier.size(18.dp)) }
                        ) {
                            if (creating) return@GoldButton
                            creating = true
                            scope.launch {
                                try { shareBattle(context, appState.battles.createInvitation(exercise)) } catch (e: Exception) { error = e.message } finally { creating = false }
                            }
                        }
                        Text(
                            "Invites expire after 24 hours. Once a friend joins, you both have 24 hours for your one 60-second run.",
                            style = rounded(12, FontWeight.Medium), color = Pc.mist.copy(alpha = 0.8f)
                        )
                    }
                    Column(Modifier.fillMaxWidth().battleCard().padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                            Icon(Icons.Filled.Code, null, tint = Pc.iconBlue, modifier = Modifier.size(32.dp))
                            Column {
                                Text("Join with Code", style = serif(23), color = Pc.ivory)
                                Text("Enter your friend's code to join the battle.", style = rounded(14, FontWeight.Medium), color = Pc.mist)
                            }
                        }
                        Box(Modifier.fillMaxWidth().height(52.dp).recessed().padding(horizontal = 14.dp), contentAlignment = Alignment.CenterStart) {
                            if (code.isEmpty()) Text("Enter battle code", style = rounded(20, FontWeight.Bold, 1.5f), color = Pc.mist.copy(alpha = 0.5f))
                            BasicTextField(
                                code, { v -> code = v.uppercase().filter { it.isLetterOrDigit() }.take(6) },
                                singleLine = true, textStyle = rounded(20, FontWeight.Bold, 1.5f).copy(color = Pc.ivory),
                                cursorBrush = SolidColor(Pc.amberSoft),
                                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Characters, autoCorrectEnabled = false),
                                modifier = Modifier.fillMaxWidth()
                            )
                        }
                        GoldButton("Fight", isLoading = joining, icon = { CrossedSwordsIcon(Pc.buttonInk, Modifier.size(22.dp)) }) {
                            val c = code.trim().uppercase()
                            when {
                                c.isEmpty() -> error = "Enter a battle code."
                                c.length != 6 -> error = "Battle codes must be 6 letters or numbers."
                                invitation?.code == c -> error = "You can't join your own battle."
                                else -> {
                                    joining = true
                                    scope.launch {
                                        try {
                                            val b = appState.battles.join(c)
                                            code = ""
                                            Haptics.smash()
                                            nav.navigate("battle/${b.id}")
                                        } catch (e: Exception) { error = e.message } finally { joining = false }
                                    }
                                }
                            }
                        }
                    }
                }
                Segment.Active -> Column(Modifier.padding(top = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    val list = battles.active
                    if (list.isEmpty()) EmptyState(
                        { CrossedSwordsIcon(Pc.mist, Modifier.size(30.dp)) }, "No active battles yet.", "Create a battle or join a friend using their code."
                    ) { segment = Segment.Join }
                    else list.forEach { b -> ActiveBattleCard(b) { nav.navigate("battle/${b.id}") } }
                }
                Segment.Completed -> Column(Modifier.padding(top = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    val list = battles.completed
                    if (list.isEmpty()) EmptyState(
                        { Icon(Icons.Filled.EmojiEvents, null, tint = Pc.gold, modifier = Modifier.size(30.dp)) },
                        "No completed battles yet.", "Finish your first battle to see your results here."
                    ) { segment = Segment.Join }
                    else list.forEach { b -> CompletedBattleCard(b) { nav.navigate("battleResult/${b.id}") } }
                }
            }
        }
        AnimatedVisibility(copied, enter = slideInVertically() + fadeIn(), exit = slideOutVertically() + fadeOut(), modifier = Modifier.align(Alignment.TopCenter).statusBarsPadding()) {
            Row(
                Modifier.padding(top = 8.dp).shadow(12.dp, CircleShape).background(Color(0xFF1A2A4A), CircleShape).border(1.dp, Pc.amberSoft.copy(alpha = 0.5f), CircleShape)
                    .padding(horizontal = 16.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(Icons.Filled.CheckCircle, null, tint = Pc.success, modifier = Modifier.size(18.dp))
                Text("Code copied.", style = rounded(15, FontWeight.SemiBold), color = Pc.ivory)
            }
        }
    }
    error?.let { ErrorDialog("Battles", it) { error = null } }
}

@Composable
fun ErrorDialog(title: String, message: String, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss, containerColor = Pc.towersNavy,
        title = { Text(title, style = rounded(19, FontWeight.Bold), color = Pc.ivory) },
        text = { Text(message, style = rounded(15, FontWeight.Medium), color = Pc.mist) },
        confirmButton = { TextButton(onDismiss) { Text("OK", color = Pc.amberSoft) } }
    )
}

@Composable
private fun EmptyState(icon: @Composable () -> Unit, title: String, message: String, onJoin: () -> Unit) {
    Column(Modifier.fillMaxWidth().battleCard().padding(20.dp).padding(vertical = 16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Box(Modifier.padding(bottom = 4.dp)) { icon() }
        Text(title, style = rounded(18, FontWeight.Bold), color = Pc.ivory)
        Text(message, style = rounded(14, FontWeight.Medium), color = Pc.mist, textAlign = TextAlign.Center)
        GoldButton("Join a Battle", Modifier.padding(top = 12.dp), onClick = onJoin)
    }
}

@Composable
private fun ActiveBattleCard(b: Battle, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().battleCard().pressScale(onClick = onClick).padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        BattleAvatar(b.opponentName, b.opponentAvatarPath)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(b.opponentName ?: "Waiting for opponent", style = rounded(17, FontWeight.Bold), color = Pc.ivory, maxLines = 1)
            Text(b.exercise.challengeTitle, style = rounded(13, FontWeight.Medium), color = Pc.mist, maxLines = 1)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(b.statusText, style = rounded(12, FontWeight.Bold), color = if (b.phase == BattlePhase.Waiting) Pc.amberSoft else Pc.progressCyan)
                val deadline = if (b.phase == BattlePhase.Waiting) b.inviteExpiresAt else b.deadlineAt
                deadline?.let { Text("· ${relativeLeft(it)} left", style = rounded(12, FontWeight.Medium), color = Pc.mist.copy(alpha = 0.8f), maxLines = 1) }
            }
        }
        val play = b.canStartRun
        Box(
            Modifier.height(36.dp)
                .background(if (play) AmberGradient else SolidColor(Color.White.copy(alpha = 0.08f)), CircleShape)
                .border(1.dp, Color.White.copy(alpha = if (play) 0f else 0.16f), CircleShape).padding(horizontal = 14.dp),
            contentAlignment = Alignment.Center
        ) { Text(if (play) "Play" else "View", style = rounded(13, FontWeight.Bold), color = if (play) Pc.buttonInk else Pc.ivory) }
    }
}

@Composable
private fun CompletedBattleCard(b: Battle, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().battleCard().pressScale(onClick = onClick).padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        BattleAvatar(b.opponentName, b.opponentAvatarPath)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(b.opponentName ?: "No opponent", style = rounded(17, FontWeight.Bold), color = Pc.ivory, maxLines = 1)
            b.result?.let { r ->
                Text("You ${r.myScore ?: "—"} · ${b.opponentName ?: "Opponent"} ${r.opponentScore ?: "—"}", style = rounded(13, FontWeight.SemiBold), color = Pc.mist, maxLines = 1)
                Text(formatDate(r.date), style = rounded(12, FontWeight.Medium), color = Pc.mist.copy(alpha = 0.7f))
            }
        }
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(5.dp)) {
            b.result?.let { r ->
                Text(
                    r.outcome.title.uppercase(), style = rounded(11, FontWeight.Bold, 0.8f), color = r.outcome.color,
                    modifier = Modifier.background(r.outcome.color.copy(alpha = 0.14f), CircleShape).padding(horizontal = 10.dp, vertical = 4.dp)
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("View Result", style = rounded(12, FontWeight.SemiBold), color = Pc.mist)
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Pc.mist, modifier = Modifier.size(14.dp))
            }
        }
    }
}

/** Battle details: opponent, rules, deadline, both statuses and the action. */
@Composable
fun BattleDetailsScreen(appState: AppState, battleId: String, nav: NavController, host: WorkoutHost) {
    val context = LocalContext.current
    val battles by appState.battles.battles.collectAsState()
    val dashboard by appState.progress.dashboard.collectAsState()
    val battle = battles.firstOrNull { it.id == battleId }
    var starting by remember { mutableStateOf(false) }
    var cancelling by remember { mutableStateOf(false) }
    var confirmCancel by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) { runCatching { appState.battles.load() } }
    LaunchedEffect(host.session) { if (host.session == null) runCatching { appState.battles.load() } }
    LaunchedEffect(battle?.phase) {
        if (battle?.phase == BattlePhase.Completed && host.session == null) {
            nav.navigate("battleResult/$battleId") { popUpTo("battle/$battleId") { inclusive = true } }
        }
    }

    Column(
        Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Pc.journeyTop, Pc.night))).statusBarsPadding()
            .verticalScroll(rememberScrollState()).padding(16.dp).padding(bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        BackTextButton { nav.popBackStack() }
        if (battle == null) {
            Text("This battle is no longer available.", style = rounded(16, FontWeight.SemiBold), color = Pc.mist, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(top = 40.dp))
            return@Column
        }
        Row(Modifier.padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            BattleAvatar(battle.opponentName, battle.opponentAvatarPath, 64.dp)
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("BATTLE · ${battle.code}", style = rounded(11, FontWeight.Bold, 2f), color = Pc.mist)
                Text(battle.opponentName ?: "Waiting for opponent", style = rounded(25, FontWeight.Bold), color = Pc.ivory, maxLines = 1)
                Text(battle.statusText, style = rounded(14, FontWeight.Bold), color = if (battle.phase == BattlePhase.Waiting) Pc.amberSoft else Pc.progressCyan)
            }
        }
        Column(Modifier.fillMaxWidth().battleCard().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                CrossedSwordsIcon(Pc.iconBlue, Modifier.size(26.dp))
                Text(battle.exercise.challengeTitle, style = rounded(19, FontWeight.Bold), color = Pc.ivory)
            }
            Text(battle.exercise.challengeDescription, style = rounded(14, FontWeight.Medium), color = Pc.mist)
            Text(
                "Both players perform ${battle.exercise.unitName}. One run each, camera counted. Reach 30 reps to also earn XP and a streak day.",
                style = rounded(12, FontWeight.Bold), color = Pc.progressCyan
            )
        }
        Column(Modifier.fillMaxWidth().battleCard().padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                SectionLabel("STATUS", modifier = Modifier.weight(1f))
                val deadline = if (battle.phase == BattlePhase.Waiting) battle.inviteExpiresAt else battle.deadlineAt
                if (deadline != null && deadline.isAfter(Instant.now())) {
                    Icon(Icons.Filled.Schedule, null, tint = Pc.amberSoft, modifier = Modifier.size(14.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("${relativeLeft(deadline)} left", style = rounded(12, FontWeight.Bold), color = Pc.amberSoft)
                }
            }
            StatusRow("You", if (battle.mySubmitted) "${battle.myScore ?: 0} ${battle.exercise.unitName}" else if (battle.myRunStarted) "Run in progress" else "Not played yet", battle.mySubmitted)
            StatusRow(
                battle.opponentName ?: "Opponent",
                if (battle.opponentName == null) "Not joined" else if (battle.opponentSubmitted) "Submitted · hidden until the end" else "Not played yet",
                battle.opponentSubmitted
            )
        }
        when (battle.phase) {
            BattlePhase.Active -> if (battle.canStartRun) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    GoldButton(
                        if (battle.myRunStarted) "Resume Battle" else "Start Battle", isLoading = starting,
                        icon = { CrossedSwordsIcon(Pc.buttonInk, Modifier.size(22.dp)) }
                    ) {
                        if (starting) return@GoldButton
                        val pending = appState.workouts.pendingRun(battle.id)
                        if (pending != null && pending.state != PendingSession.REGISTERING) {
                            scope.launch { appState.workouts.syncPending(); runCatching { appState.battles.load() } }
                            error = "Your run for this battle is already saved and is syncing."
                            return@GoldButton
                        }
                        starting = true
                        scope.launch {
                            try {
                                host.session = appState.workouts.start(battle.exercise, battle.id, dashboard?.rules)
                            } catch (e: Exception) {
                                error = e.message
                                runCatching { appState.battles.load() }
                            } finally { starting = false }
                        }
                    }
                    Text(
                        "You get one 60-second run. Starting needs an internet connection; once started, your reps are kept even if the connection drops.",
                        style = rounded(12, FontWeight.Medium), color = Pc.mist.copy(alpha = 0.8f)
                    )
                }
            } else if (battle.myRunStarted && !battle.mySubmitted) {
                Text("Your run is saved on this phone and will sync automatically.", style = rounded(13, FontWeight.Medium), color = Pc.mist)
            }
            BattlePhase.Waiting -> Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                GoldButton("Share Code", icon = { Icon(Icons.Filled.Share, null, tint = Pc.buttonInk, modifier = Modifier.size(18.dp)) }) { shareBattle(context, battle) }
                if (battle.isHost) {
                    Box(Modifier.fillMaxWidth().height(44.dp).pressScale(!cancelling) { confirmCancel = true }, contentAlignment = Alignment.Center) {
                        Text(if (cancelling) "Cancelling…" else "Cancel Invitation", style = rounded(15, FontWeight.SemiBold), color = Color(0xFFFF8A8A))
                    }
                }
            }
            BattlePhase.Completed -> GoldButton("View Result", icon = { Icon(Icons.Filled.EmojiEvents, null, tint = Pc.buttonInk, modifier = Modifier.size(18.dp)) }) {
                nav.navigate("battleResult/$battleId")
            }
        }
    }
    if (confirmCancel) {
        AlertDialog(
            onDismissRequest = { confirmCancel = false }, containerColor = Pc.towersNavy,
            title = { Text("Cancel this invitation?", style = rounded(19, FontWeight.Bold), color = Pc.ivory) },
            text = { Text("The code stops working and nobody can join.", style = rounded(15, FontWeight.Medium), color = Pc.mist) },
            confirmButton = {
                TextButton({
                    confirmCancel = false
                    cancelling = true
                    scope.launch {
                        try { appState.battles.cancel(battleId); nav.popBackStack() } catch (e: Exception) { error = e.message } finally { cancelling = false }
                    }
                }) { Text("Cancel Invitation", color = Pc.danger) }
            },
            dismissButton = { TextButton({ confirmCancel = false }) { Text("Keep It", color = Pc.amberSoft) } }
        )
    }
    error?.let { ErrorDialog("Battle", it) { error = null } }
}

@Composable
private fun StatusRow(label: String, value: String, done: Boolean) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Icon(if (done) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked, null, tint = if (done) Pc.success else Pc.mist.copy(alpha = 0.7f), modifier = Modifier.size(20.dp))
        Text(label, style = rounded(15, FontWeight.Bold), color = Pc.ivory, maxLines = 1)
        Spacer(Modifier.weight(1f))
        Text(value, style = rounded(13, FontWeight.SemiBold), color = Pc.mist, maxLines = 1)
    }
}

/** Battle result: outcome, both scores and a return to Battles. */
@Composable
fun BattleResultScreen(appState: AppState, battleId: String, nav: NavController) {
    val battles by appState.battles.battles.collectAsState()
    val battle = battles.firstOrNull { it.id == battleId }
    LaunchedEffect(Unit) { runCatching { appState.battles.load() } }
    Column(
        Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Pc.journeyTop, Pc.night))).statusBarsPadding()
            .verticalScroll(rememberScrollState()).padding(16.dp).padding(top = 40.dp, bottom = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        val result = battle?.result
        if (battle != null && result != null) {
            val icon = when (result.outcome) {
                BattleOutcome.Victory -> Icons.Filled.EmojiEvents
                BattleOutcome.Defeat -> Icons.Filled.Cancel
                BattleOutcome.Draw -> Icons.Filled.DragHandle
                BattleOutcome.Expired -> Icons.Filled.HourglassEmpty
            }
            Icon(icon, null, tint = result.outcome.color, modifier = Modifier.size(48.dp))
            Text(result.outcome.title, style = rounded(40, FontWeight.ExtraBold), color = result.outcome.color)
            Text("vs ${battle.opponentName ?: "No opponent"}", style = rounded(17, FontWeight.SemiBold), color = Pc.mist)
            Row(Modifier.padding(top = 6.dp).fillMaxWidth().battleCard().padding(vertical = 20.dp), verticalAlignment = Alignment.CenterVertically) {
                ScoreColumn("YOU", result.myScore, battle.exercise.unitName, Pc.progressCyan, Modifier.weight(1f))
                Box(Modifier.width(1.dp).height(56.dp).background(Color.White.copy(alpha = 0.12f)))
                ScoreColumn((battle.opponentName ?: "OPPONENT").uppercase(), result.opponentScore, battle.exercise.unitName, Pc.mist, Modifier.weight(1f))
            }
            val date = formatDate(result.date)
            Text(
                when {
                    result.outcome == BattleOutcome.Expired -> "Expired $date · no scores were submitted in time"
                    result.myScore == null || result.opponentScore == null -> "Decided $date · the other player didn't submit before the deadline"
                    else -> "Completed $date"
                },
                style = rounded(13, FontWeight.Medium), color = Pc.mist.copy(alpha = 0.8f), textAlign = TextAlign.Center
            )
        } else {
            androidx.compose.material3.CircularProgressIndicator(color = Pc.amberSoft, modifier = Modifier.padding(top = 80.dp))
            Text("The result isn't final yet.", style = rounded(15, FontWeight.SemiBold), color = Pc.mist)
        }
        GoldButton(
            "Back to Battles", Modifier.padding(top = 10.dp),
            icon = { Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Pc.buttonInk, modifier = Modifier.size(20.dp)) }
        ) { nav.popBackStack("battles", inclusive = false) }
    }
}

@Composable
private fun ScoreColumn(label: String, score: Int?, unit: String, color: Color, modifier: Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(label, style = rounded(12, FontWeight.Bold, 1.5f), color = Pc.mist, maxLines = 1)
        Text(score?.toString() ?: "—", style = rounded(44, FontWeight.ExtraBold), color = color)
        Text(if (score == null) "no score" else unit, style = rounded(12, FontWeight.Medium), color = Pc.mist.copy(alpha = 0.8f))
    }
}

package com.tinochiwara.pushcraft.ui.onboarding

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.scaleIn
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
import androidx.compose.foundation.layout.aspectRatio
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
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountBalance
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Checkroom
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.NotificationsOff
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Accessibility
import androidx.compose.material.icons.filled.Done
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.tinochiwara.pushcraft.R
import com.tinochiwara.pushcraft.data.AppState
import com.tinochiwara.pushcraft.data.Haptics
import com.tinochiwara.pushcraft.data.OnboardingModel
import com.tinochiwara.pushcraft.data.OnboardingStep
import com.tinochiwara.pushcraft.data.Reminders
import com.tinochiwara.pushcraft.model.HeightUnit
import com.tinochiwara.pushcraft.model.OnboardingChoice
import com.tinochiwara.pushcraft.model.Weekday
import com.tinochiwara.pushcraft.ui.components.pressScale
import com.tinochiwara.pushcraft.ui.theme.Pc
import com.tinochiwara.pushcraft.ui.theme.rounded
import com.tinochiwara.pushcraft.ui.theme.sans
import com.tinochiwara.pushcraft.ui.theme.serif
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter

// MARK: - Welcome

@Composable
fun WelcomeScreen(onStart: () -> Unit, onSignIn: () -> Unit) {
    var appeared by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { appeared = true }
    val a by animateFloatAsState(if (appeared) 1f else 0f, tween(1200), label = "w")
    Box(Modifier.fillMaxSize()) {
        Image(
            painterResource(R.drawable.onboarding_welcome_bg), null,
            modifier = Modifier.fillMaxSize().scale(1.06f - 0.06f * a),
            contentScale = ContentScale.Crop, alignment = Alignment.TopCenter
        )
        Box(Modifier.fillMaxSize().background(Brush.verticalGradient(0.5f to Color.Transparent, 0.74f to Pc.obNavyDeep.copy(alpha = 0.8f), 1f to Pc.obNavyDeep)))
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
            Column(
                Modifier.fillMaxWidth().padding(top = 10.dp).alpha(a).offset(y = (-12 * (1 - a)).dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text("Pushcraft", style = serif(48).copy(brush = Brush.verticalGradient(listOf(Pc.amberSoft, Pc.amberDeep))))
                Text("Build strength. Craft your tower.", style = rounded(17, FontWeight.SemiBold), color = Pc.ivory.copy(alpha = 0.92f))
            }
            Spacer(Modifier.weight(1f))
            Column(
                Modifier.padding(horizontal = 24.dp).padding(bottom = 12.dp).alpha(a).offset(y = (20 * (1 - a)).dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                OnboardingPrimaryButton("Get started", onClick = onStart)
                OnboardingSecondaryButton("I already have an account", onClick = onSignIn)
            }
        }
    }
}

// MARK: - Auth buttons

@Composable
fun AuthButtons(appState: AppState, onStart: () -> Unit = {}) {
    val busy by appState.isAuthenticating.collectAsState()
    Box(contentAlignment = Alignment.Center) {
        Column(Modifier.alpha(if (busy) 0.55f else 1f), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            val shape = RoundedCornerShape(18.dp)
            Row(
                Modifier.fillMaxWidth().height(56.dp).background(Color.White, shape)
                    .pressScale(!busy) { onStart(); appState.signInWithGoogle() },
                horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically
            ) {
                Image(painterResource(R.drawable.logo_google), null, Modifier.size(20.dp))
                Spacer(Modifier.width(10.dp))
                Text("Continue with Google", style = sans(18, FontWeight.SemiBold), color = Color.Black)
            }
            Row(
                Modifier.fillMaxWidth().height(56.dp).background(Pc.obCard, shape).border(1.dp, Color.White.copy(alpha = 0.22f), shape)
                    .pressScale(!busy) { onStart(); appState.signInWithApple() },
                horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically
            ) {
                Image(painterResource(R.drawable.logo_apple), null, Modifier.size(20.dp), colorFilter = ColorFilter.tint(Pc.ivory))
                Spacer(Modifier.width(10.dp))
                Text("Continue with Apple", style = sans(18, FontWeight.SemiBold), color = Pc.ivory)
            }
        }
        if (busy) CircularProgressIndicator(color = Pc.amberSoft)
    }
}

@Composable
fun ExistingAccountScreen(appState: AppState) {
    LaunchedEffect(Unit) { appState.onboarding.awaitingSignUp = false }
    Column(Modifier.fillMaxSize().padding(horizontal = 24.dp).navigationBarsPadding().padding(bottom = 12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Spacer(Modifier.height(12.dp).weight(0.3f))
        Image(painterResource(R.drawable.golem), null, Modifier.height(230.dp))
        Text("Welcome back", style = serif(32), color = Pc.ivory, modifier = Modifier.padding(top = 18.dp))
        Text("Sign in to keep building your towers.", style = rounded(16, FontWeight.Medium), color = Pc.mist, modifier = Modifier.padding(top = 6.dp))
        Spacer(Modifier.weight(1f))
        AuthButtons(appState)
        Spacer(Modifier.height(14.dp))
        LegalLine()
    }
}

// MARK: - Meet guide

@Composable
fun MeetGuideScreen() {
    var showGolem by remember { mutableStateOf(false) }
    var showBubble by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        showGolem = true
        delay(550)
        Haptics.thud()
        showBubble = true
    }
    val g by animateFloatAsState(if (showGolem) 1f else 0f, spring(dampingRatio = 0.8f, stiffness = 120f), label = "g")
    Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
        Spacer(Modifier.weight(0.2f))
        Box(Modifier.heightIn(min = 96.dp).padding(horizontal = 24.dp)) {
            androidx.compose.animation.AnimatedVisibility(showBubble, enter = scaleIn(initialScale = 0.85f) + fadeIn()) {
                SpeechBubble("Welcome, builder. Every great tower starts with a foundation. Let's find yours.", fontSize = 20)
            }
        }
        Image(
            painterResource(R.drawable.golem), null,
            Modifier.padding(top = 22.dp).widthIn(max = 360.dp).heightIn(max = 360.dp).alpha(g).offset(y = (30 * (1 - g)).dp)
        )
        Spacer(Modifier.weight(0.2f))
        Text("A few questions, then your first build.", style = rounded(15, FontWeight.Medium), color = Pc.mist, modifier = Modifier.padding(bottom = 110.dp))
    }
}

// MARK: - Name

@Composable
fun NameScreen(model: OnboardingModel) {
    val focus = remember { FocusRequester() }
    var focused by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { delay(450); runCatching { focus.requestFocus() } }
    OnboardingScaffold("What should we call you?") {
        val shape = RoundedCornerShape(18.dp)
        Box(
            Modifier.fillMaxWidth().height(64.dp).background(Pc.obCard, shape)
                .border(if (focused) 2.dp else 1.dp, if (focused) Pc.amberSoft else Pc.obCardBorder, shape)
                .padding(horizontal = 20.dp),
            contentAlignment = Alignment.CenterStart
        ) {
            if (model.name.isEmpty()) Text("Your name", style = rounded(24, FontWeight.SemiBold), color = Pc.mist.copy(alpha = 0.6f))
            BasicTextField(
                value = model.name,
                onValueChange = { model.name = it.take(30) },
                singleLine = true,
                textStyle = rounded(24, FontWeight.SemiBold).copy(color = Pc.ivory),
                cursorBrush = SolidColor(Pc.amberSoft),
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Next),
                keyboardActions = KeyboardActions(onNext = { model.advance(OnboardingStep.MainGoal) }),
                modifier = Modifier.fillMaxWidth().focusRequester(focus)
                    .onFocusChanged { focused = it.isFocused }
            )
        }
    }
}


// MARK: - Choices

@Composable
fun <T : OnboardingChoice> SingleChoiceScreen(title: String, helper: String? = null, options: List<T>, selection: T?, onSelect: (T) -> Unit) {
    OnboardingScaffold(title, helper) { OptionList(options, selection, onSelect) }
}

@Composable
fun <T : OnboardingChoice> OptionList(options: List<T>, selection: T?, onSelect: (T) -> Unit) {
    var appeared by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { appeared = true }
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        options.forEachIndexed { i, choice ->
            val a by animateFloatAsState(if (appeared) 1f else 0f, tween(450, delayMillis = i * 50), label = "o$i")
            OnboardingOptionRow(choice.title, choice.icon, selection == choice, modifier = Modifier.alpha(a).offset(y = (14 * (1 - a)).dp)) { onSelect(choice) }
        }
    }
}

@Composable
fun <T : OnboardingChoice> StatementScreen(title: String, statement: String, options: List<T>, selection: T?, onSelect: (T) -> Unit) {
    OnboardingScaffold(title) {
        Column(verticalArrangement = Arrangement.spacedBy(22.dp)) {
            StatementCard(statement)
            OptionList(options, selection, onSelect)
        }
    }
}

// MARK: - Age (snapping wheel)

@Composable
fun AgeScreen(model: OnboardingModel) {
    val ages = (13..100).toList()
    OnboardingScaffold("How old are you?", scrolls = false) {
        WheelPicker(
            values = ages,
            selected = model.ageYears,
            rowHeight = 68,
            label = { "$it" },
            textSize = 44,
            trailing = "years",
            onChange = { model.ageYears = it },
            modifier = Modifier.fillMaxWidth().height(360.dp)
        )
    }
}

/** Vertical snapping wheel with a highlighted center row. */
@Composable
fun WheelPicker(
    values: List<Int>,
    selected: Int,
    rowHeight: Int,
    label: (Int) -> String,
    textSize: Int,
    trailing: String?,
    onChange: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    val start = values.indexOf(selected).coerceAtLeast(0)
    val state = rememberLazyListState(initialFirstVisibleItemIndex = start)
    val fling = rememberSnapFlingBehavior(state)
    LaunchedEffect(state) {
        snapshotFlow { state.firstVisibleItemIndex + if (state.firstVisibleItemScrollOffset > rowHeight * 1.5f) 1 else 0 }
            .collect { idx ->
                val v = values.getOrNull(idx) ?: return@collect
                if (v != selected) { onChange(v); Haptics.tick() }
            }
    }
    BoxWithConstraints(modifier, contentAlignment = Alignment.Center) {
        val pad = (maxHeight - rowHeight.dp) / 2
        Box(
            Modifier.fillMaxWidth().height(rowHeight.dp)
                .background(Pc.amberSoft.copy(alpha = 0.1f), RoundedCornerShape(20.dp))
                .border(1.5.dp, Pc.amberSoft.copy(alpha = 0.7f), RoundedCornerShape(20.dp))
        )
        LazyColumn(
            state = state, flingBehavior = fling,
            contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = pad),
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            items(values.size) { i ->
                val v = values[i]
                Box(Modifier.fillMaxWidth().height(rowHeight.dp), contentAlignment = Alignment.Center) {
                    Text(
                        label(v), style = rounded(textSize, FontWeight.Bold),
                        color = if (v == selected) Pc.amberSoft else Pc.ivory.copy(alpha = 0.45f),
                        modifier = Modifier.scale(if (v == selected) 1f else 0.72f)
                    )
                }
            }
        }
        trailing?.let {
            Text(it, style = rounded(17, FontWeight.SemiBold), color = Pc.mist, modifier = Modifier.align(Alignment.CenterEnd).padding(end = 36.dp))
        }
    }
}

// MARK: - Height

@Composable
fun HeightScreen(model: OnboardingModel) {
    OnboardingScaffold("How tall are you?", "Choose your preferred units.", scrolls = false) {
        Column(verticalArrangement = Arrangement.spacedBy(18.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Row(
                Modifier.widthIn(max = 240.dp).background(Pc.obCard, CircleShape).border(1.dp, Pc.obCardBorder, CircleShape).padding(4.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                HeightUnit.entries.forEach { unit ->
                    val sel = model.heightUnit == unit
                    Box(
                        Modifier.weight(1f).height(40.dp).background(if (sel) Pc.amberSoft else Color.Transparent, CircleShape)
                            .pressScale { if (!sel) { Haptics.selection(); model.heightUnit = unit } },
                        contentAlignment = Alignment.Center
                    ) { Text(unit.title, style = rounded(15, FontWeight.Bold), color = if (sel) Pc.buttonInk else Pc.mist) }
                }
            }
            val text = if (model.heightUnit == HeightUnit.Cm) "${Math.round(model.heightCm)}" to "cm"
            else Math.round(model.heightCm / 2.54).toInt().let { "${it / 12}′ ${it % 12}″" to "" }
            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(text.first, style = rounded(56, FontWeight.Bold), color = Pc.ivory)
                Text(text.second, style = rounded(22, FontWeight.SemiBold), color = Pc.mist, modifier = Modifier.padding(bottom = 12.dp))
            }
            val isCm = model.heightUnit == HeightUnit.Cm
            val values = if (isCm) (50..250).reversed().toList() else (20..98).reversed().toList()
            val current = if (isCm) Math.round(model.heightCm).toInt() else Math.round(model.heightCm / 2.54).toInt()
            androidx.compose.runtime.key(model.heightUnit) {
                WheelPicker(
                    values = values, selected = current, rowHeight = 44,
                    label = { v -> if (isCm) "$v" else "${v / 12}′ ${v % 12}″" },
                    textSize = 26, trailing = null,
                    onChange = { v -> model.heightCm = if (isCm) v.toDouble() else v * 2.54 },
                    modifier = Modifier.fillMaxWidth().height(260.dp).clip(RoundedCornerShape(24.dp)).background(Pc.obCard.copy(alpha = 0.6f))
                )
            }
        }
    }
}

// MARK: - Workout days

@Composable
fun WorkoutDaysScreen(model: OnboardingModel) {
    OnboardingScaffold("Which days would you like to build?", "Choose a routine that works for you. You can change it later.") {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Weekday.entries.chunked(2).forEach { pair ->
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    pair.forEach { day ->
                        val sel = day.iso in model.workoutDays
                        val shape = RoundedCornerShape(18.dp)
                        Row(
                            Modifier.weight(1f).height(60.dp)
                                .background(if (sel) Pc.amberSoft.copy(alpha = 0.12f) else Pc.obCard.copy(alpha = 0.85f), shape)
                                .border(if (sel) 2.dp else 1.dp, if (sel) Pc.amberSoft else Pc.obCardBorder, shape)
                                .pressScale {
                                    Haptics.selection()
                                    if (sel) model.workoutDays.remove(day.iso) else model.workoutDays.add(day.iso)
                                }
                                .padding(horizontal = 12.dp),
                            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            Box(
                                Modifier.size(44.dp, 32.dp).background(if (sel) Pc.amberSoft else Pc.amberSoft.copy(alpha = 0.12f), RoundedCornerShape(10.dp)),
                                contentAlignment = Alignment.Center
                            ) { Text(day.short.uppercase(), style = rounded(13, FontWeight.ExtraBold, 1f), color = if (sel) Pc.buttonInk else Pc.amberSoft) }
                            Text(day.title, style = rounded(16, FontWeight.SemiBold), color = Pc.ivory, maxLines = 1)
                        }
                    }
                    if (pair.size == 1) Spacer(Modifier.weight(1f))
                }
            }
            val count = model.workoutDays.size
            Text(
                if (count == 0) "Pick at least one day" else if (count == 1) "1 day each week" else "$count days each week",
                style = rounded(16, FontWeight.Bold), color = if (count == 0) Pc.mist else Pc.amberSoft,
                textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(top = 6.dp)
            )
        }
    }
}

// MARK: - Reminder

@Composable
fun ReminderScreen(model: OnboardingModel) {
    OnboardingScaffold("Daily build reminder", "What is the best time for you to build?") {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            val shape = RoundedCornerShape(18.dp)
            Row(
                Modifier.fillMaxWidth().heightIn(min = 68.dp).background(Pc.obCard, shape).border(1.dp, Pc.obCardBorder, shape).padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Box(Modifier.size(40.dp).background(Pc.amberSoft.copy(alpha = 0.12f), RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) {
                    Icon(Icons.Filled.NotificationsActive, null, tint = Pc.amberSoft, modifier = Modifier.size(20.dp))
                }
                Text("Remind me", style = rounded(18, FontWeight.SemiBold), color = Pc.ivory, modifier = Modifier.weight(1f))
                Switch(
                    model.remindersRequested,
                    { Haptics.selection(); model.remindersRequested = it; model.showDeniedMessage = false },
                    colors = SwitchDefaults.colors(checkedTrackColor = Pc.amberDeep, checkedThumbColor = Color.White)
                )
            }
            AnimatedVisibility(model.remindersRequested) {
                Column(
                    Modifier.fillMaxWidth().background(Pc.obCard.copy(alpha = 0.7f), RoundedCornerShape(20.dp)).padding(vertical = 18.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                        TimeStepper(Icons.Filled.Remove) { model.reminderMinutes = (model.reminderMinutes - 15 + 1440) % 1440; Haptics.tick() }
                        val h = model.reminderMinutes / 60
                        val m = model.reminderMinutes % 60
                        val ampm = if (h < 12) "AM" else "PM"
                        val h12 = if (h % 12 == 0) 12 else h % 12
                        Text("%d:%02d %s".format(h12, m, ampm), style = rounded(40, FontWeight.Bold), color = Pc.ivory)
                        TimeStepper(Icons.Filled.Add) { model.reminderMinutes = (model.reminderMinutes + 15) % 1440; Haptics.tick() }
                    }
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Icon(Icons.Filled.CalendarMonth, null, tint = Pc.ivory, modifier = Modifier.size(16.dp))
                        Text(model.selectedDaysText, style = rounded(15, FontWeight.SemiBold), color = Pc.ivory)
                    }
                    Text(
                        "Times use your local time zone (${java.util.TimeZone.getDefault().getDisplayName(false, java.util.TimeZone.LONG)}).",
                        style = rounded(13, FontWeight.Medium), color = Pc.mist, textAlign = TextAlign.Center, modifier = Modifier.padding(horizontal = 16.dp)
                    )
                }
            }
            if (model.showDeniedMessage) {
                Row(
                    Modifier.fillMaxWidth().background(Color(0x993A1E12), RoundedCornerShape(16.dp)).padding(16.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Icon(Icons.Filled.NotificationsOff, null, tint = Pc.ivory, modifier = Modifier.size(18.dp))
                    Text("Reminders are off. You can turn them on in Settings later.", style = rounded(15, FontWeight.SemiBold), color = Pc.ivory)
                }
            }
        }
    }
}

@Composable
private fun TimeStepper(icon: androidx.compose.ui.graphics.vector.ImageVector, onClick: () -> Unit) {
    Box(
        Modifier.size(44.dp).background(Pc.amberSoft.copy(alpha = 0.14f), CircleShape).border(1.dp, Pc.amberSoft.copy(alpha = 0.5f), CircleShape).pressScale(onClick = onClick),
        contentAlignment = Alignment.Center
    ) { Icon(icon, null, tint = Pc.amberSoft) }
}

/** Requests notification permission when needed, then finishes the step. */
@Composable
fun rememberReminderAction(model: OnboardingModel, appState: AppState): () -> Unit {
    val context = LocalContext.current
    val finish = {
        model.applyReminderPreferences()
        if (com.tinochiwara.pushcraft.data.AppPreferences.notificationsEnabled) Reminders.schedule(context, false, 0)
        model.advance(OnboardingStep.FirstBuild)
    }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        model.notificationStatus = if (granted) "authorized" else "denied"
        if (granted) { Haptics.success(); finish() } else { Haptics.warning(); model.showDeniedMessage = true }
    }
    return {
        if (!model.remindersRequested || model.showDeniedMessage) {
            if (!model.remindersRequested) model.notificationStatus = model.notificationStatus
            finish()
        } else if (Reminders.hasPermission(context)) {
            model.notificationStatus = "authorized"
            finish()
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            launcher.launch(Manifest.permission.POST_NOTIFICATIONS)
        } else finish()
    }
}

// MARK: - Journey + How to build

@Composable
fun TowerJourneyScreen(onReady: () -> Unit) {
    var showTitle by remember { mutableStateOf(false) }
    var showGolem by remember { mutableStateOf(false) }
    var showBubble by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(450); showTitle = true
        delay(2000); showGolem = true
        delay(750); Haptics.thud(); showBubble = true
        delay(500); onReady()
    }
    val t by animateFloatAsState(if (showTitle) 1f else 0f, tween(600), label = "t")
    val g by animateFloatAsState(if (showGolem) 1f else 0f, tween(700), label = "g")
    Box(Modifier.fillMaxSize()) {
        BoxWithConstraints(Modifier.fillMaxSize()) {
            val imgW = 853f; val imgH = 1844f
            val scale = maxOf(constraints.maxWidth / imgW, constraints.maxHeight / imgH)
            val dw = imgW * scale; val dh = imgH * scale
            val ox = (constraints.maxWidth - dw) / 2; val oy = (constraints.maxHeight - dh) / 2
            val density = androidx.compose.ui.platform.LocalDensity.current
            with(density) {
                Image(
                    painterResource(R.drawable.onboarding_journey_bg), null, contentScale = ContentScale.FillBounds,
                    modifier = Modifier.offset(ox.toDp(), oy.toDp()).size(dw.toDp(), dh.toDp())
                )
                val bw = dw * 0.36f
                StartHereBadge(
                    OnboardingModel.FIRST_TOWER_NAME, bw.toDp(),
                    Modifier.offset((ox + dw * 0.299f - bw / 2).toDp(), (oy + dh * 0.798f - bw * 0.2f).toDp())
                )
            }
        }
        Box(Modifier.fillMaxSize().background(Brush.verticalGradient(0f to Pc.obNavyDeep.copy(alpha = 0.75f), 0.38f to Color.Transparent)))
        Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text("Your tower journey", style = serif(30), color = Pc.ivory, modifier = Modifier.padding(start = 24.dp, top = 12.dp).alpha(t))
            Row(Modifier.padding(horizontal = 18.dp), verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Image(painterResource(R.drawable.golem), null, Modifier.size(104.dp).alpha(g).scale(0.85f + 0.15f * g))
                AnimatedVisibility(showBubble, enter = scaleIn(initialScale = 0.85f) + fadeIn(), modifier = Modifier.padding(top = 10.dp, start = 10.dp)) {
                    SpeechBubble("Every rep brings you closer to your next tower. Let's start building.", fontSize = 17, tailLeading = true)
                }
            }
        }
    }
}

@Composable
private fun StartHereBadge(towerName: String, width: androidx.compose.ui.unit.Dp, modifier: Modifier = Modifier) {
    val w = width.value
    Column(modifier.width(width), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            "START HERE", style = serif((w * 0.075f).toInt().coerceAtLeast(8), FontWeight.ExtraBold, 0.5f), color = Color(0xFF2A1A06),
            modifier = Modifier.background(Brush.verticalGradient(listOf(Color(0xFFFFD98A), Color(0xFFE2A23A))), CircleShape)
                .padding(horizontal = (w * 0.07f).dp, vertical = (w * 0.018f).dp)
        )
        Box(
            Modifier.offset(y = (-w * 0.03f).dp).width((w * 0.92f).dp).height((w * 0.25f).dp)
                .background(Color(0xFF14244A), RoundedCornerShape((w * 0.05f).dp))
                .border(1.5.dp, Brush.verticalGradient(listOf(Color(0xFFFFD98A), Color(0xFFB37A22))), RoundedCornerShape((w * 0.05f).dp)),
            contentAlignment = Alignment.Center
        ) { Text(towerName, style = serif((w * 0.15f).toInt().coerceAtLeast(10)), color = Pc.ivory, maxLines = 1) }
    }
}

@Composable
fun HowBuildScreen(onReady: () -> Unit) {
    var show by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { delay(400); show = true; delay(1200); onReady() }
    val a by animateFloatAsState(if (show) 1f else 0f, tween(700), label = "hb")
    Column(Modifier.fillMaxSize().background(Color(0xFF051A3A))) {
        OnboardingHeader("How to build", "Every rep builds something.", Modifier.padding(horizontal = 24.dp).padding(top = 12.dp))
        Image(painterResource(R.drawable.onboarding_build_bg), "Do push-ups, break blocks, build your tower.", Modifier.fillMaxWidth().weight(1f).alpha(a), contentScale = ContentScale.Fit)
        Spacer(Modifier.height(100.dp))
    }
}

// MARK: - First build

@Composable
fun FirstBuildScreen(model: OnboardingModel) {
    var show by remember { mutableStateOf(false) }
    var bubble by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { show = true; delay(500); Haptics.thud(); bubble = true }
    val s by animateFloatAsState(if (show) 1f else 0f, spring(dampingRatio = 0.85f, stiffness = 120f), label = "fb")
    Column(Modifier.fillMaxSize()) {
        OnboardingHeader("Your first build starts here", modifier = Modifier.padding(horizontal = 24.dp).padding(top = 12.dp))
        Spacer(Modifier.weight(0.3f))
        Box(Modifier.heightIn(min = 76.dp).padding(horizontal = 24.dp)) {
            androidx.compose.animation.AnimatedVisibility(bubble, enter = scaleIn(initialScale = 0.85f) + fadeIn()) {
                SpeechBubble("Ready, ${model.nameOrBuilder}? Let's put your first effort into ${OnboardingModel.FIRST_TOWER_NAME}.")
            }
        }
        Box(Modifier.fillMaxWidth().padding(top = 70.dp).alpha(s).scale(0.92f + 0.08f * s), contentAlignment = Alignment.BottomCenter) {
            Box(Modifier.size(340.dp, 90.dp).offset(y = 10.dp).background(Brush.radialGradient(listOf(Pc.amberSoft.copy(alpha = 0.35f), Color.Transparent)), androidx.compose.foundation.shape.GenericShape { size, _ -> addOval(androidx.compose.ui.geometry.Rect(0f, 0f, size.width, size.height)) }))
            Image(painterResource(R.drawable.oakspire_foundation), "The empty foundation where Oakspire will rise", Modifier.widthIn(max = 300.dp))
            Image(painterResource(R.drawable.golem), null, Modifier.size(170.dp).offset(x = (-96).dp, y = (-92).dp))
        }
        Spacer(Modifier.weight(0.3f))
        Spacer(Modifier.height(100.dp))
    }
}

// MARK: - Instructions & tips

@Composable
fun InstructionScreen(title: String, body1: String, body2: String? = null, image: Int, aspect: Float = 1f) {
    var appeared by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { appeared = true }
    val a by animateFloatAsState(if (appeared) 1f else 0f, spring(dampingRatio = 0.85f, stiffness = 150f), label = "in")
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 140.dp),
        verticalArrangement = Arrangement.spacedBy(22.dp)
    ) {
        OnboardingHeader(title)
        Image(painterResource(image), null, Modifier.fillMaxWidth().aspectRatio(aspect).alpha(a).scale(0.95f + 0.05f * a).clip(RoundedCornerShape(16.dp)), contentScale = ContentScale.Fit)
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(body1, style = rounded(19, FontWeight.SemiBold), color = Pc.ivory)
            body2?.let { Text(it, style = rounded(16, FontWeight.Medium), color = Pc.mist) }
        }
    }
}

@Composable
fun DetectionTipsScreen() {
    val tips = listOf(
        Icons.Filled.Accessibility to "Make sure you back up enough so your whole body is in frame.",
        Icons.Filled.Lightbulb to "Make sure the background is well-lit.",
        Icons.Filled.Checkroom to "Tuck in any baggy clothes."
    )
    var appeared by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { appeared = true }
    OnboardingScaffold("Detection Tips") {
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            tips.forEachIndexed { i, (icon, text) ->
                val a by animateFloatAsState(if (appeared) 1f else 0f, tween(500, delayMillis = i * 100), label = "tip$i")
                val shape = RoundedCornerShape(20.dp)
                Row(
                    Modifier.fillMaxWidth().alpha(a).offset(x = (24 * (1 - a)).dp).background(Pc.obCard, shape).border(1.dp, Pc.obCardBorder, shape).padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    Box(Modifier.size(52.dp).background(Pc.amberSoft.copy(alpha = 0.12f), RoundedCornerShape(16.dp)), contentAlignment = Alignment.Center) {
                        Icon(icon, null, tint = Pc.amberSoft, modifier = Modifier.size(24.dp))
                    }
                    Text(text, style = rounded(17, FontWeight.SemiBold), color = Pc.ivory)
                }
            }
        }
    }
}

// MARK: - First reward

@Composable
fun FirstRewardScreen(model: OnboardingModel) {
    var built by remember { mutableStateOf(false) }
    var bubble by remember { mutableStateOf(false) }
    val sparkle = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        delay(500); Haptics.thud(); built = true
        launch { delay(400); sparkle.animateTo(1f, tween(1200)) }
        delay(700); bubble = true
    }
    val b by animateFloatAsState(if (built) 1f else 0f, tween(1100), label = "b")
    val reps = model.introRepsDone ?: 0
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 140.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp), horizontalAlignment = Alignment.CenterHorizontally
    ) {
        OnboardingHeader("Your first progress, earned")
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
            Image(painterResource(R.drawable.golem), null, Modifier.size(92.dp))
            androidx.compose.animation.AnimatedVisibility(bubble, enter = scaleIn(initialScale = 0.85f) + fadeIn(), modifier = Modifier.padding(top = 8.dp, start = 12.dp)) {
                SpeechBubble("That's your effort, ${model.nameOrBuilder}. Your first build is underway.", fontSize = 17, tailLeading = true)
            }
        }
        Box(Modifier.widthIn(max = 320.dp), contentAlignment = Alignment.Center) {
            Image(painterResource(R.drawable.oakspire_foundation), null, Modifier.fillMaxWidth().alpha(1 - b))
            Image(painterResource(R.drawable.oakspire_foundation_built), null, Modifier.fillMaxWidth().alpha(b).scale(0.96f + 0.04f * b))
            Canvas(Modifier.matchParentSize()) {
                val c = Offset(size.width / 2, size.height / 2)
                for (i in 0 until 8) {
                    val ang = i / 8.0 * 2 * Math.PI
                    val p = c + Offset((Math.cos(ang) * 150 * sparkle.value * density / 2.5).toFloat(), (Math.sin(ang) * 80 * sparkle.value * density / 2.5).toFloat())
                    drawCircle(Pc.gold.copy(alpha = if (built) 1 - sparkle.value else 0f), 5.dp.toPx(), p)
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Metric(if (reps == 1) "1" else "$reps", if (reps == 1) "push-up" else "push-ups", Icons.Filled.FitnessCenter, Modifier.weight(1f))
            Metric(OnboardingModel.FIRST_TOWER_NAME, OnboardingModel.FIRST_STAGE_NAME, Icons.Filled.AccountBalance, Modifier.weight(1f))
        }
        Text(
            "A preview of your first tower. Your reps start building for real once you save your progress.",
            style = rounded(13, FontWeight.Medium), color = Pc.mist, textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun Metric(value: String, label: String, icon: androidx.compose.ui.graphics.vector.ImageVector, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(18.dp)
    Row(
        modifier.background(Pc.obCard, shape).border(1.dp, Pc.obCardBorder, shape).padding(12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(Modifier.size(40.dp).background(Pc.amberSoft.copy(alpha = 0.12f), RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = Pc.amberSoft, modifier = Modifier.size(20.dp))
        }
        Column {
            Text(value, style = rounded(19, FontWeight.Bold), color = Pc.ivory, maxLines = 1)
            Text(label, style = rounded(13, FontWeight.Medium), color = Pc.mist, maxLines = 1)
        }
    }
}

// MARK: - Forecast

@Composable
fun ForecastScreen(model: OnboardingModel) {
    val date = model.forecastDate
    val dateText = date?.let {
        if (it.year == LocalDate.now().year) it.format(DateTimeFormatter.ofPattern("MMM d")) else it.format(DateTimeFormatter.ofPattern("MMM d, yyyy"))
    } ?: "soon"
    val days = model.workoutDays.size
    val daysText = if (days == 1) "1 day a week" else "$days days a week"
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp).padding(top = 12.dp, bottom = 140.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp)
    ) {
        OnboardingHeader("Your first tower is within reach by $dateText")
        Text("You have amazing potential!", style = rounded(18, FontWeight.Bold).copy(brush = Brush.horizontalGradient(listOf(Pc.gold, Pc.amberDeep))))
        ForecastGraph(dateText)
        Text(
            "At ${OnboardingModel.SESSION_GOAL} reps per session, $daysText, you could finish ${OnboardingModel.FIRST_TOWER_NAME} around $dateText.",
            style = rounded(17, FontWeight.SemiBold), color = Pc.ivory
        )
        Text("Every rep brings you closer to your next tower", style = rounded(13, FontWeight.Medium), color = Pc.mist)
    }
}

@Composable
private fun ForecastGraph(endLabel: String) {
    val progress = remember { Animatable(0f) }
    var showTower by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(250)
        launch { progress.animateTo(1f, tween(1600)) }
        delay(1550); Haptics.thud(); showTower = true
    }
    val t by animateFloatAsState(if (showTower) 1f else 0f, spring(dampingRatio = 0.6f), label = "tw")
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        BoxWithConstraints(
            Modifier.fillMaxWidth().height(250.dp).background(Pc.obCard.copy(alpha = 0.6f), RoundedCornerShape(22.dp)).border(1.dp, Pc.obCardBorder, RoundedCornerShape(22.dp))
        ) {
            val d = androidx.compose.ui.platform.LocalDensity.current
            val wPx = constraints.maxWidth.toFloat(); val hPx = constraints.maxHeight.toFloat()
            val start = with(d) { Offset(14.dp.toPx(), hPx - 14.dp.toPx()) }
            val end = with(d) { Offset(wPx - 34.dp.toPx(), 38.dp.toPx()) }
            Canvas(Modifier.fillMaxSize()) {
                for (l in 1..3) {
                    val y = size.height * l / 4
                    drawLine(Color.White.copy(alpha = 0.08f), Offset(0f, y), Offset(size.width, y), 1f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(10f, 14f)))
                }
                val c1 = Offset(start.x + (end.x - start.x) * 0.45f, start.y)
                val c2 = Offset(start.x + (end.x - start.x) * 0.7f, end.y + (start.y - end.y) * 0.25f)
                val curve = Path().apply { moveTo(start.x, start.y); cubicTo(c1.x, c1.y, c2.x, c2.y, end.x, end.y) }
                val area = Path().apply { addPath(curve); lineTo(end.x, size.height); lineTo(start.x, size.height); close() }
                drawPath(area, Brush.verticalGradient(listOf(Pc.amberSoft.copy(alpha = 0.32f * progress.value), Color.Transparent)))
                val measure = androidx.compose.ui.graphics.PathMeasure().apply { setPath(curve, false) }
                val seg = Path()
                measure.getSegment(0f, measure.length * progress.value, seg, true)
                drawPath(seg, Brush.horizontalGradient(listOf(Pc.amberDeep, Pc.gold)), style = Stroke(5.dp.toPx(), cap = StrokeCap.Round))
                drawCircle(Pc.amberDeep, 7.dp.toPx(), start)
                drawCircle(Pc.ivory, 4.dp.toPx(), start)
            }
            with(d) {
                Image(
                    painterResource(R.drawable.paywall_tower), null,
                    Modifier.offset((end.x - 29.dp.toPx()).toDp(), (end.y - 35.dp.toPx()).toDp()).size(58.dp).scale(0.2f + 0.8f * t).alpha(t)
                )
            }
        }
        Row(Modifier.fillMaxWidth().padding(horizontal = 6.dp)) {
            Text("Today", style = rounded(14, FontWeight.Bold), color = Pc.mist)
            Spacer(Modifier.weight(1f))
            Text(endLabel, style = rounded(14, FontWeight.Bold), color = Pc.mist)
        }
    }
}

// MARK: - Save progress

@Composable
fun SaveProgressScreen(appState: AppState) {
    val model = appState.onboarding
    Column(Modifier.fillMaxSize().navigationBarsPadding()) {
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Box(Modifier.fillMaxWidth().height(190.dp).padding(top = 8.dp)) {
                Image(
                    painterResource(if (model.didIntroWorkout) R.drawable.oakspire_foundation_built else R.drawable.oakspire_foundation), null,
                    Modifier.width(210.dp).align(Alignment.BottomCenter).offset(x = 50.dp)
                )
                Image(painterResource(R.drawable.golem), null, Modifier.size(170.dp).align(Alignment.BottomStart).offset(y = 10.dp))
            }
            Text("Save your progress", style = serif(32), color = Pc.ivory, textAlign = TextAlign.Center)
            Text(
                if (model.didIntroWorkout) "Keep your tower progress and continue your journey." else "Save your starting goal and begin your journey.",
                style = rounded(17, FontWeight.Medium), color = Pc.mist, textAlign = TextAlign.Center
            )
        }
        Column(Modifier.padding(horizontal = 24.dp).padding(bottom = 12.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            AuthButtons(appState) { model.awaitingSignUp = true }
            LegalLine()
        }
    }
}

// MARK: - Setup progress (post sign-up)

@Composable
fun SetupProgressScreen(appState: AppState) {
    val titles = listOf("Setting up your profile", "Building your workout plan", "Generating your tower roadmap")
    val progress = remember { mutableStateListOf(0f, 0f, 0f) }
    LaunchedEffect(Unit) {
        val save = launch { appState.completeOnboardingSave() }
        for (i in titles.indices) {
            val a = Animatable(0f)
            launch { a.animateTo(1f, tween(1300)) { progress[i] = value } }
            delay(1350)
            Haptics.success()
        }
        save.join()
        delay(350)
        appState.onboarding.finishSetup()
    }
    Box(Modifier.fillMaxSize()) {
        OnboardingBackground()
        Column(
            Modifier.fillMaxSize().padding(horizontal = 28.dp), verticalArrangement = Arrangement.spacedBy(34.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Image(painterResource(R.drawable.golem), null, Modifier.size(170.dp))
            Text("We're setting everything up for you", style = serif(28), color = Pc.ivory, textAlign = TextAlign.Center)
            Column(verticalArrangement = Arrangement.spacedBy(22.dp)) {
                titles.forEachIndexed { i, title ->
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(title, style = rounded(16, FontWeight.SemiBold), color = Pc.ivory, modifier = Modifier.weight(1f))
                            val done = progress[i] >= 1f
                            Box(
                                Modifier.size(18.dp).background(if (done) Pc.gold else Color.Transparent, CircleShape)
                                    .border(2.dp, if (done) Pc.gold else Pc.mist.copy(alpha = 0.6f), CircleShape),
                                contentAlignment = Alignment.Center
                            ) { if (done) Icon(androidx.compose.material.icons.Icons.Default.Done, null, tint = Pc.night, modifier = Modifier.size(12.dp)) }
                        }
                        BoxWithConstraints(Modifier.fillMaxWidth().height(10.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.1f))) {
                            Box(Modifier.height(10.dp).width(maxWidth * progress[i]).background(Brush.horizontalGradient(listOf(Pc.amberSoft, Pc.amberDeep)), CircleShape))
                        }
                    }
                }
            }
        }
    }
}

@Suppress("unused")
private val keepShadow = Modifier.shadow(0.dp)

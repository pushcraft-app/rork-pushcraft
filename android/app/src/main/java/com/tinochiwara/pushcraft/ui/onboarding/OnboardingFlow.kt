package com.tinochiwara.pushcraft.ui.onboarding

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.AlertDialog
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.tinochiwara.pushcraft.R
import com.tinochiwara.pushcraft.data.AppState
import com.tinochiwara.pushcraft.data.OnboardingStep
import com.tinochiwara.pushcraft.data.OnboardingStep.*
import com.tinochiwara.pushcraft.model.Agreement
import com.tinochiwara.pushcraft.model.ExerciseFrequency
import com.tinochiwara.pushcraft.model.ExperienceLevel
import com.tinochiwara.pushcraft.model.GenderChoice
import com.tinochiwara.pushcraft.model.MainGoal
import com.tinochiwara.pushcraft.model.PushupCapacity
import com.tinochiwara.pushcraft.ui.theme.Pc
import com.tinochiwara.pushcraft.ui.theme.rounded
import com.tinochiwara.pushcraft.ui.workout.IntroWorkoutScreen

private data class StepCTA(val title: String, val enabled: Boolean = true, val secondary: String? = null)

/** Signed-out experience: Welcome → questionnaire → first build → sign up. */
@Composable
fun OnboardingFlow(appState: AppState) {
    val model = appState.onboarding
    val step = model.step
    var ctaVisible by remember { mutableStateOf(true) }
    LaunchedEffect(step) { ctaVisible = step != Journey && step != HowBuild }
    val authError by appState.authError.collectAsState()
    val reminderAction = rememberReminderAction(model, appState)

    BackHandler(enabled = model.canGoBack) { model.back() }

    val showsTopBar = step != Welcome && step != IntroWorkout
    val cta: StepCTA? = when (step) {
        MeetGuide -> StepCTA("Let's begin")
        Name, Age, Height, Journey, HowBuild, FirstReward, Forecast -> StepCTA("Continue")
        OnboardingStep.MainGoal -> StepCTA("Continue", model.mainGoal != null)
        Experience -> StepCTA("Continue", model.experience != null)
        Gender -> StepCTA("Continue", model.gender != null)
        Frequency -> StepCTA("Continue", model.frequency != null)
        Boredom -> StepCTA("Continue", model.boredom != null)
        Equipment -> StepCTA("Continue", model.equipment != null)
        SeeingProgress -> StepCTA("Continue", model.seeingProgress != null)
        OnboardingStep.PushupCapacity -> StepCTA("Continue", model.pushupCapacity != null)
        WorkoutDays -> StepCTA("Continue", model.workoutDays.isNotEmpty())
        Reminder -> StepCTA(model.reminderPrimaryTitle, secondary = "Not now")
        FirstBuild -> StepCTA("I'm ready")
        PhoneSetup, PushupForm -> StepCTA("Next")
        DetectionTips -> StepCTA("Start", secondary = "I can't do push-ups right now")
        else -> null
    }

    fun primary() {
        when (step) {
            MeetGuide -> model.advance(Name)
            Name -> model.advance(OnboardingStep.MainGoal)
            OnboardingStep.MainGoal -> model.advance(Experience)
            Experience -> model.advance(Gender)
            Gender -> model.advance(Age)
            Age -> { model.hasConfirmedAge = true; model.advance(Height) }
            Height -> { model.hasConfirmedHeight = true; model.advance(Frequency) }
            Frequency -> model.advance(Boredom)
            Boredom -> model.advance(Equipment)
            Equipment -> model.advance(SeeingProgress)
            SeeingProgress -> model.advance(Journey)
            Journey -> model.advance(HowBuild)
            HowBuild -> model.advance(OnboardingStep.PushupCapacity)
            OnboardingStep.PushupCapacity -> model.advance(WorkoutDays)
            WorkoutDays -> model.advance(Reminder)
            Reminder -> reminderAction()
            FirstBuild -> model.advance(PhoneSetup)
            PhoneSetup -> model.advance(PushupForm)
            PushupForm -> model.advance(DetectionTips)
            DetectionTips -> model.advance(IntroWorkout)
            FirstReward -> model.advance(Forecast)
            Forecast -> model.advance(SaveProgress)
            else -> Unit
        }
    }

    fun secondary() {
        when (step) {
            Reminder -> { model.remindersRequested = false; reminderAction() }
            DetectionTips -> model.advance(Forecast)
            else -> Unit
        }
    }

    Box(Modifier.fillMaxSize()) {
        OnboardingBackground()
        AnimatedContent(
            targetState = step,
            transitionSpec = {
                if (targetState == Journey || targetState == HowBuild || initialState == Journey || initialState == HowBuild) {
                    fadeIn(tween(350)) togetherWith fadeOut(tween(250))
                } else {
                    val dir = if (model.isForward) 1 else -1
                    (slideInHorizontally(tween(380)) { it * dir } + fadeIn()) togetherWith (slideOutHorizontally(tween(380)) { -it * dir / 3 } + fadeOut())
                }
            },
            label = "onboarding"
        ) { s ->
            Box(Modifier.fillMaxSize().then(if (s != Welcome && s != IntroWorkout) Modifier.statusBarsPadding().padding(top = 50.dp) else Modifier)) {
                Screen(s, appState)
            }
        }
        if (showsTopBar) {
            Box(Modifier.statusBarsPadding().padding(top = 3.dp)) {
                OnboardingTopBar(step.progress, model.canGoBack) { model.back() }
            }
        }
        if (cta != null) {
            val a by animateFloatAsState(if (ctaVisible) 1f else 0f, tween(350), label = "cta")
            Box(Modifier.fillMaxSize().alpha(a), contentAlignment = Alignment.BottomCenter) {
                PersistentCTA(cta.title, cta.enabled && ctaVisible, false, cta.secondary, ::primary, ::secondary)
            }
        }
    }

    authError?.let { msg ->
        AlertDialog(
            onDismissRequest = { appState.authError.value = null },
            containerColor = Pc.obNavy,
            title = { Text("Sign in", style = rounded(19, FontWeight.Bold), color = Pc.ivory) },
            text = { Text(msg, style = rounded(15, FontWeight.Medium), color = Pc.mist) },
            confirmButton = { TextButton({ appState.authError.value = null }) { Text("OK", color = Pc.amberSoft) } }
        )
    }
}

@Composable
private fun Screen(step: OnboardingStep, appState: AppState) {
    val model = appState.onboarding
    when (step) {
        Welcome -> WelcomeScreen({ model.advance(MeetGuide) }, { model.advance(SignIn) })
        SignIn -> ExistingAccountScreen(appState)
        MeetGuide -> MeetGuideScreen()
        Name -> NameScreen(model)
        OnboardingStep.MainGoal -> SingleChoiceScreen("What brings you to Pushcraft?", null, com.tinochiwara.pushcraft.model.MainGoal.entries, model.mainGoal) { model.mainGoal = it }
        Experience -> SingleChoiceScreen("How experienced are you with exercise?", null, ExperienceLevel.entries, model.experience) { model.experience = it }
        Gender -> SingleChoiceScreen("What's your gender?", "This helps us personalize your experience.", GenderChoice.entries, model.gender) { model.gender = it }
        Age -> AgeScreen(model)
        Height -> HeightScreen(model)
        Frequency -> SingleChoiceScreen("How often do you exercise now?", "Think about a typical week.", ExerciseFrequency.entries, model.frequency) { model.frequency = it }
        Boredom -> StatementScreen("Does this sound like you?", "I start motivated, but ordinary workouts get boring.", Agreement.entries, model.boredom) { model.boredom = it }
        Equipment -> StatementScreen("Does this get in your way?", "Getting to a gym or finding equipment makes exercise harder to fit in.", Agreement.entries, model.equipment) { model.equipment = it }
        SeeingProgress -> StatementScreen("What about this?", "It's harder to stay consistent when I can't see my progress.", Agreement.entries, model.seeingProgress) { model.seeingProgress = it }
        Journey -> TowerJourneyScreen {}
        HowBuild -> HowBuildScreen {}
        OnboardingStep.PushupCapacity -> SingleChoiceScreen(
            "How many push-ups can you comfortably do in one set?", "An estimate is fine. You don't need to test your maximum.",
            com.tinochiwara.pushcraft.model.PushupCapacity.entries, model.pushupCapacity
        ) { model.pushupCapacity = it }
        WorkoutDays -> WorkoutDaysScreen(model)
        Reminder -> ReminderScreen(model)
        FirstBuild -> FirstBuildScreen(model)
        PhoneSetup -> InstructionScreen(
            "Set up your phone", "Place your phone securely on the floor with the camera facing you.",
            "Use a clear, well-lit space where you have room to move.", R.drawable.onboarding_setup_phone, 1594f / 987f
        )
        PushupForm -> InstructionScreen(
            "Get into position", "Place your entire body in the frame and begin doing push-ups. The video won't leave your device.",
            null, R.drawable.onboarding_pushup_movement
        )
        DetectionTips -> DetectionTipsScreen()
        IntroWorkout -> IntroWorkoutScreen(onFinish = { model.finishIntro(it) }, onSkip = { model.advance(Forecast) })
        FirstReward -> FirstRewardScreen(model)
        Forecast -> ForecastScreen(model)
        SaveProgress -> SaveProgressScreen(appState)
    }
}

@Suppress("unused")
private val keepVisibility: @Composable () -> Unit = { AnimatedVisibility(true) { Column {} } }

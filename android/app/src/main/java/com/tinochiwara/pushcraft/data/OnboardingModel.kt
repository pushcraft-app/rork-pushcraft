package com.tinochiwara.pushcraft.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.tinochiwara.pushcraft.model.Agreement
import com.tinochiwara.pushcraft.model.ExerciseFrequency
import com.tinochiwara.pushcraft.model.ExperienceLevel
import com.tinochiwara.pushcraft.model.GenderChoice
import com.tinochiwara.pushcraft.model.HeightUnit
import com.tinochiwara.pushcraft.model.MainGoal
import com.tinochiwara.pushcraft.model.OnboardingAnswers
import com.tinochiwara.pushcraft.model.PushupCapacity
import com.tinochiwara.pushcraft.model.Weekday
import java.time.LocalDate
import java.time.ZoneId

/** Every screen in the first-run flow. */
enum class OnboardingStep {
    Welcome, SignIn,
    MeetGuide, Name, MainGoal, Experience, Gender, Age, Height,
    Frequency, Boredom, Equipment, SeeingProgress, Journey, HowBuild,
    PushupCapacity, WorkoutDays, Reminder,
    FirstBuild, PhoneSetup, PushupForm, DetectionTips, IntroWorkout, FirstReward, Forecast, SaveProgress;

    val progress: Float?
        get() {
            val index = questionnaire.indexOf(this)
            return if (index < 0) null else (index + 1).toFloat() / questionnaire.size
        }

    companion object {
        val questionnaire = listOf(
            MeetGuide, Name, MainGoal, Experience, Gender, Age, Height,
            Frequency, Boredom, Equipment, SeeingProgress, Journey, HowBuild,
            PushupCapacity, WorkoutDays, Reminder
        )
    }
}

/**
 * Answers and navigation for onboarding. Compose snapshot state so screens
 * recompose directly; lives on AppState to survive the sign-up switch.
 */
class OnboardingModel {
    companion object {
        const val FIRST_TOWER_NAME = "Oakspire"
        const val FIRST_STAGE_NAME = "The Foundation"
        const val FIRST_TOWER_REPS = 450
        const val SESSION_GOAL = 30
        const val INTRO_REPS = 4
    }

    val history = mutableStateListOf(OnboardingStep.Welcome)
    var isForward by mutableStateOf(true)
        private set

    var name by mutableStateOf("")
    var mainGoal by mutableStateOf<MainGoal?>(null)
    var experience by mutableStateOf<ExperienceLevel?>(null)
    var gender by mutableStateOf<GenderChoice?>(null)
    var ageYears by mutableStateOf(25)
    var hasConfirmedAge by mutableStateOf(false)
    var heightCm by mutableStateOf(170.0)
    var heightUnit by mutableStateOf(HeightUnit.Cm)
    var hasConfirmedHeight by mutableStateOf(false)
    var frequency by mutableStateOf<ExerciseFrequency?>(null)
    var boredom by mutableStateOf<Agreement?>(null)
    var equipment by mutableStateOf<Agreement?>(null)
    var seeingProgress by mutableStateOf<Agreement?>(null)
    var pushupCapacity by mutableStateOf<PushupCapacity?>(null)
    val workoutDays = mutableStateListOf<Int>()
    var remindersRequested by mutableStateOf(false)
    var reminderMinutes by mutableStateOf(18 * 60)
    var notificationStatus by mutableStateOf<String?>(null)
    var showDeniedMessage by mutableStateOf(false)
    var introRepsDone by mutableStateOf<Int?>(null)
        private set

    var awaitingSignUp by mutableStateOf(false)
    var isSettingUp by mutableStateOf(false)
        private set

    val step: OnboardingStep get() = history.lastOrNull() ?: OnboardingStep.Welcome

    val canGoBack: Boolean
        get() = when (step) {
            OnboardingStep.Welcome, OnboardingStep.IntroWorkout, OnboardingStep.FirstReward -> false
            OnboardingStep.Forecast -> !didIntroWorkout && history.size > 1
            else -> history.size > 1
        }

    val trimmedName: String get() = name.trim().take(30)
    val nameOrBuilder: String get() = trimmedName.ifEmpty { "builder" }
    val didIntroWorkout: Boolean get() = introRepsDone != null

    fun advance(next: OnboardingStep) {
        isForward = true
        history.add(next)
    }

    fun back() {
        if (!canGoBack) return
        isForward = false
        history.removeAt(history.lastIndex)
    }

    fun finishIntro(reps: Int) {
        introRepsDone = reps
        advance(OnboardingStep.FirstReward)
    }

    fun beginSetupIfNeeded() {
        if (!awaitingSignUp) return
        awaitingSignUp = false
        isSettingUp = true
    }

    fun finishSetup() {
        isSettingUp = false
    }

    fun reset() {
        history.clear(); history.add(OnboardingStep.Welcome)
        isForward = true
        name = ""; mainGoal = null; experience = null; gender = null
        ageYears = 25; hasConfirmedAge = false
        heightCm = 170.0; heightUnit = HeightUnit.Cm; hasConfirmedHeight = false
        frequency = null; boredom = null; equipment = null; seeingProgress = null
        pushupCapacity = null; workoutDays.clear(); remindersRequested = false
        reminderMinutes = 18 * 60; notificationStatus = null; showDeniedMessage = false
        introRepsDone = null; awaitingSignUp = false; isSettingUp = false
    }

    /** Date of the session that would finish the first tower on the chosen days. */
    val forecastDate: LocalDate?
        get() {
            if (workoutDays.isEmpty()) return null
            val needed = Math.ceil(FIRST_TOWER_REPS.toDouble() / SESSION_GOAL).toInt()
            var sessions = 0
            val start = LocalDate.now()
            for (offset in 0 until 730) {
                val date = start.plusDays(offset.toLong())
                if (date.dayOfWeek.value in workoutDays) {
                    sessions++
                    if (sessions == needed) return date
                }
            }
            return null
        }

    val selectedDaysText: String
        get() {
            val days = Weekday.entries.filter { it.iso in workoutDays }
            return if (days.size == 7) "Every day" else days.joinToString(", ") { it.short }
        }

    val reminderPrimaryTitle: String
        get() = if (remindersRequested && !showDeniedMessage && notificationStatus != "denied") "Enable reminders" else "Continue"

    fun makeAnswers(): OnboardingAnswers = OnboardingAnswers(
        displayName = trimmedName.ifEmpty { null },
        mainGoal = mainGoal?.serverValue,
        experience = experience?.serverValue,
        gender = gender?.serverValue,
        ageYears = if (hasConfirmedAge) ageYears else null,
        heightCm = if (hasConfirmedHeight) Math.round(heightCm * 10) / 10.0 else null,
        heightDisplayUnit = if (hasConfirmedHeight) heightUnit.raw else null,
        currentFrequency = frequency?.serverValue,
        barrierBoredom = boredom?.serverValue,
        barrierEquipment = equipment?.serverValue,
        barrierProgress = seeingProgress?.serverValue,
        pushupCapacity = pushupCapacity?.serverValue,
        workoutDays = workoutDays.sorted(),
        remindersRequested = remindersRequested,
        reminderLocalTime = if (remindersRequested) "%02d:%02d".format(reminderMinutes / 60, reminderMinutes % 60) else null,
        timezone = ZoneId.systemDefault().id,
        notificationStatus = notificationStatus,
        introWorkoutReps = introRepsDone
    )

    /** Copies the reminder choice into the phone's notification preferences. */
    fun applyReminderPreferences() {
        AppPreferences.notificationsEnabled = remindersRequested && notificationStatus == "authorized"
        AppPreferences.reminderMinutes = reminderMinutes
        AppPreferences.reminderDays = workoutDays.sorted()
    }
}

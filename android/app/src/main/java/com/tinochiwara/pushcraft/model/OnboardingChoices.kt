package com.tinochiwara.pushcraft.model

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.material.icons.filled.Spa
import androidx.compose.ui.graphics.vector.ImageVector

/** A single-choice onboarding answer. `serverValue` is what gets stored. */
interface OnboardingChoice {
    val title: String
    val serverValue: String
    val icon: ImageVector? get() = null
}

enum class MainGoal(override val serverValue: String, override val title: String, override val icon: ImageVector) : OnboardingChoice {
    Strength("strength", "Get stronger", Icons.Filled.FitnessCenter),
    MoreReps("more_reps", "Do more push-ups", Icons.Filled.Repeat),
    Consistency("consistency", "Build a consistent habit", Icons.Filled.CalendarMonth),
    Fun("fun", "Make exercise more fun", Icons.Filled.SportsEsports),
    Challenge("challenge", "Challenge myself", Icons.Filled.EmojiEvents)
}

enum class ExperienceLevel(override val serverValue: String, override val title: String, override val icon: ImageVector) : OnboardingChoice {
    Beginner("new", "I'm just starting", Icons.Filled.Spa),
    Some("some", "I've exercised before", Icons.Filled.DirectionsWalk),
    Regular("regular", "I exercise regularly", Icons.Filled.DirectionsRun)
}

enum class GenderChoice(override val serverValue: String, override val title: String) : OnboardingChoice {
    Man("man", "Male"),
    Woman("woman", "Female"),
    Undisclosed("undisclosed", "Prefer not to say")
}

enum class ExerciseFrequency(override val serverValue: String, override val title: String) : OnboardingChoice {
    NoneRegular("none_regular", "Not regularly"),
    OneTwo("one_two", "1–2 days a week"),
    ThreeFour("three_four", "3–4 days a week"),
    FivePlus("five_plus", "5+ days a week")
}

enum class Agreement(override val serverValue: String, override val title: String) : OnboardingChoice {
    Yes("yes", "Yes"),
    Sometimes("sometimes", "Sometimes"),
    No("no", "Not really")
}

enum class PushupCapacity(override val serverValue: String, override val title: String) : OnboardingChoice {
    Zero("zero", "I'm still working toward my first"),
    OneFive("one_five", "1–5"),
    SixTen("six_ten", "6–10"),
    ElevenTwenty("eleven_twenty", "11–20"),
    TwentyoneThirty("twentyone_thirty", "21–30"),
    ThirtyonePlus("thirtyone_plus", "31+"),
    Unknown("unknown", "I'm not sure")
}

enum class HeightUnit(val raw: String, val title: String) { Cm("cm", "cm"), FtIn("ft_in", "ft / in") }

/** ISO weekdays: 1 = Monday … 7 = Sunday. */
enum class Weekday(val iso: Int, val title: String) {
    Monday(1, "Monday"), Tuesday(2, "Tuesday"), Wednesday(3, "Wednesday"), Thursday(4, "Thursday"),
    Friday(5, "Friday"), Saturday(6, "Saturday"), Sunday(7, "Sunday");

    val short: String get() = title.take(3)
}

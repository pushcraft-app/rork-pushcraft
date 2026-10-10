package com.tinochiwara.pushcraft.game

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.BackHand
import androidx.compose.material.icons.filled.CenterFocusStrong
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import com.tinochiwara.pushcraft.model.Exercise
import com.tinochiwara.pushcraft.ui.theme.Pc

/** The single instruction shown under the depth meter. */
enum class CoachCue {
    GetInFrame, HoldTop, GoDown, SmashIt, Smashed;

    fun title(exercise: Exercise): String = when (this) {
        GetInFrame -> "GET IN FRAME"
        HoldTop -> "HOLD THE START"
        GoDown -> if (exercise == Exercise.SitUps) "SIT UP TO CHARGE" else "GO DOWN TO CHARGE"
        SmashIt -> if (exercise == Exercise.SitUps) "SIT UP — SMASH IT!" else "PUSH UP — SMASH IT!"
        Smashed -> "BLOCK SMASHED!"
    }

    fun subtitle(exercise: Exercise): String? = when (this) {
        GetInFrame -> if (exercise == Exercise.SitUps) "Prop your phone up to the side, then lie on your back"
        else "Prop your phone up facing you, then get into a plank"
        HoldTop -> if (exercise == Exercise.SitUps) "Lie flat, stay still — calibrating" else "Arms straight, stay still — calibrating"
        GoDown, SmashIt -> null
        Smashed -> "A tougher block is dropping in"
    }

    val tint: Color
        get() = when (this) {
            GetInFrame, GoDown -> Pc.cyan
            HoldTop -> Color.White
            SmashIt, Smashed -> Pc.gold
        }

    val icon: ImageVector?
        get() = when (this) {
            GetInFrame -> Icons.Filled.CenterFocusStrong
            HoldTop -> Icons.Filled.BackHand
            Smashed -> Icons.Filled.AutoAwesome
            else -> null
        }

    val showsChevrons: Boolean get() = this == GoDown || this == SmashIt
}

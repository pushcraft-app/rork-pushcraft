package com.rork.pushcraftandroid.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// Response shapes of the database functions (snake_case on the wire).

@Serializable
data class DashboardDTO(
    val profile: ProfileDTO,
    val stats: StatsDTO,
    val rules: RulesDTO,
    val towers: List<TowerDefinitionDTO>,
    val stages: List<StageDefinitionDTO>,
    val progress: List<TowerProgressDTO>
)

@Serializable
data class ProfileDTO(
    val id: String,
    @SerialName("display_name") val displayName: String,
    @SerialName("avatar_path") val avatarPath: String? = null,
    val timezone: String = "UTC"
)

@Serializable
data class StatsDTO(
    @SerialName("total_reps") val totalReps: Int = 0,
    @SerialName("push_up_reps") val pushUpReps: Int = 0,
    @SerialName("sit_up_reps") val sitUpReps: Int = 0,
    @SerialName("total_sessions") val totalSessions: Int = 0,
    @SerialName("completed_workouts") val completedWorkouts: Int = 0,
    @SerialName("completed_towers") val completedTowers: Int = 0,
    @SerialName("coins_balance") val coinsBalance: Int = 0,
    @SerialName("xp_total") val xpTotal: Int = 0,
    @SerialName("current_streak") val currentStreak: Int = 0,
    @SerialName("longest_streak") val longestStreak: Int = 0,
    @SerialName("last_streak_date") val lastStreakDate: String? = null,
    @SerialName("overflow_reps") val overflowReps: Int = 0
)

@Serializable
data class RulesDTO(
    val version: Int = 1,
    @SerialName("completion_reps") val completionReps: Int = 30,
    @SerialName("xp_per_completed") val xpPerCompleted: Int = 100,
    @SerialName("battle_duration_seconds") val battleDurationSeconds: Int = 60
)

@Serializable
data class TowerDefinitionDTO(
    val id: String,
    val name: String,
    @SerialName("sort_order") val sortOrder: Int,
    @SerialName("art_key") val artKey: String? = null
)

@Serializable
data class StageDefinitionDTO(
    @SerialName("tower_id") val towerId: String,
    @SerialName("stage_number") val stageNumber: Int,
    val name: String,
    @SerialName("reps_required") val repsRequired: Int
)

@Serializable
data class TowerProgressDTO(
    @SerialName("tower_id") val towerId: String,
    val status: String,
    @SerialName("current_stage") val currentStage: Int,
    @SerialName("reps_into_stage") val repsIntoStage: Int,
    @SerialName("stage_target") val stageTarget: Int
)

@Serializable
data class StartSessionDTO(
    @SerialName("session_id") val sessionId: String,
    @SerialName("started_at") val startedAt: String,
    val exercise: String,
    val source: String,
    @SerialName("battle_id") val battleId: String? = null,
    @SerialName("rules_version") val rulesVersion: Int = 1,
    val status: String = ""
)

/** The accepted, stored outcome of one workout. Retries return this same value. */
@Serializable
data class WorkoutOutcomeDTO(
    @SerialName("session_id") val sessionId: String,
    val exercise: String,
    val source: String,
    @SerialName("battle_id") val battleId: String? = null,
    @SerialName("end_reason") val endReason: String,
    val reps: Int,
    @SerialName("reps_reported") val repsReported: Int = 0,
    @SerialName("blocks_smashed") val blocksSmashed: Int = 0,
    @SerialName("coins_awarded") val coinsAwarded: Int = 0,
    @SerialName("xp_awarded") val xpAwarded: Int = 0,
    @SerialName("is_completed") val isCompleted: Boolean = false,
    @SerialName("completion_reps") val completionReps: Int = 30,
    @SerialName("streak_day_awarded") val streakDayAwarded: Boolean = false,
    @SerialName("local_date") val localDate: String = "",
    val credits: List<StageCreditDTO> = emptyList(),
    @SerialName("towers_completed") val towersCompleted: List<TowerReferenceDTO> = emptyList(),
    @SerialName("overflow_reps") val overflowReps: Int = 0,
    @SerialName("battle_submission") val battleSubmission: String? = null,
    @SerialName("rules_version") val rulesVersion: Int = 1
)

@Serializable
data class StageCreditDTO(
    @SerialName("tower_id") val towerId: String,
    @SerialName("tower_name") val towerName: String,
    @SerialName("stage_number") val stageNumber: Int,
    @SerialName("stage_name") val stageName: String,
    val reps: Int,
    @SerialName("stage_target") val stageTarget: Int,
    @SerialName("stage_completed") val stageCompleted: Boolean
)

@Serializable
data class TowerReferenceDTO(
    @SerialName("tower_id") val towerId: String,
    @SerialName("tower_name") val towerName: String
)

@Serializable
data class BattleDTO(
    val id: String,
    val code: String,
    val exercise: String,
    val status: String,
    @SerialName("is_host") val isHost: Boolean,
    @SerialName("created_at") val createdAt: String,
    @SerialName("invite_expires_at") val inviteExpiresAt: String,
    @SerialName("joined_at") val joinedAt: String? = null,
    @SerialName("deadline_at") val deadlineAt: String? = null,
    @SerialName("completed_at") val completedAt: String? = null,
    @SerialName("duration_seconds") val durationSeconds: Int = 60,
    val outcome: String? = null,
    @SerialName("my_run_started") val myRunStarted: Boolean = false,
    @SerialName("my_submitted") val mySubmitted: Boolean = false,
    @SerialName("my_score") val myScore: Int? = null,
    @SerialName("my_session_id") val mySessionId: String? = null,
    val opponent: BattleOpponentDTO? = null
)

@Serializable
data class BattleOpponentDTO(
    @SerialName("user_id") val userId: String? = null,
    @SerialName("display_name") val displayName: String,
    @SerialName("avatar_path") val avatarPath: String? = null,
    val submitted: Boolean = false,
    val score: Int? = null
)

/** Onboarding answers sent to `save_onboarding`. */
@Serializable
data class OnboardingAnswers(
    @SerialName("display_name") val displayName: String? = null,
    @SerialName("main_goal") val mainGoal: String? = null,
    val experience: String? = null,
    val gender: String? = null,
    @SerialName("age_years") val ageYears: Int? = null,
    @SerialName("height_cm") val heightCm: Double? = null,
    @SerialName("height_display_unit") val heightDisplayUnit: String? = null,
    @SerialName("current_frequency") val currentFrequency: String? = null,
    @SerialName("barrier_boredom") val barrierBoredom: String? = null,
    @SerialName("barrier_equipment") val barrierEquipment: String? = null,
    @SerialName("barrier_progress") val barrierProgress: String? = null,
    @SerialName("pushup_capacity") val pushupCapacity: String? = null,
    @SerialName("workout_days") val workoutDays: List<Int> = emptyList(),
    @SerialName("reminders_requested") val remindersRequested: Boolean = false,
    @SerialName("reminder_local_time") val reminderLocalTime: String? = null,
    val timezone: String? = null,
    @SerialName("notification_status") val notificationStatus: String? = null,
    @SerialName("intro_workout_reps") val introWorkoutReps: Int? = null
)

package com.rork.pushcraftandroid.model

import java.time.Instant

/** The exercises the camera can count. One exercise per session. */
enum class Exercise(val serverValue: String, val displayName: String, val unitName: String, val actionName: String) {
    PushUps("push_ups", "Push-Ups", "push-ups", "push up"),
    SitUps("sit_ups", "Sit-Ups", "sit-ups", "sit up");

    val challengeTitle: String
        get() = if (this == PushUps) "Most push-ups in 60 seconds" else "Most sit-ups in 60 seconds"

    val challengeDescription: String
        get() = "Record as many $unitName as you can in 60 seconds. The higher count wins the battle."

    companion object {
        fun fromServer(value: String?): Exercise? = entries.firstOrNull { it.serverValue == value }
    }
}

enum class TowerStatus { Completed, InProgress, Locked }

/** One tower in the progression path. */
data class Tower(
    val id: String,
    val name: String,
    val status: TowerStatus,
    val currentStage: Int,
    val totalStages: Int,
    val totalReps: Int,
    val progress: Double,
    val stageFraction: Double = 0.0,
    val unlockedAfter: String?
) {
    val percentComplete: Int get() = Math.round(progress * 100).toInt()

    val builtStages: Int
        get() = when (status) {
            TowerStatus.Completed -> totalStages
            TowerStatus.InProgress -> maxOf(currentStage - 1, 0)
            TowerStatus.Locked -> 0
        }
}

enum class StageState { Completed, Current, Locked }

data class JourneyStage(
    val number: Int,
    val name: String,
    val state: StageState,
    val repsRequired: Int,
    val repsDone: Int
) {
    val progress: Double
        get() = if (repsRequired == 0) 0.0 else minOf(repsDone.toDouble() / repsRequired, 1.0)
}

/** Everything Home, Journey and workout prep show. */
data class HomeData(
    val streak: Int,
    val xp: Int,
    val coins: Int,
    val towerName: String,
    val stageNumber: Int,
    val totalStages: Int,
    val stageName: String,
    val repsIntoStage: Int,
    val stageTarget: Int,
    val sets: Int,
    val repsPerSet: Int,
    val estimatedMinutes: Int,
    val xpPerWorkout: Int,
    val rewardName: String,
    val journey: List<JourneyStage>,
    val isAllComplete: Boolean
) {
    val stageProgress: Double
        get() = if (stageTarget == 0) 0.0 else minOf(repsIntoStage.toDouble() / stageTarget, 1.0)
    val stagePercent: Int get() = Math.round(stageProgress * 100).toInt()
    val totalPlannedReps: Int get() = sets * repsPerSet
    val repsToGo: Int get() = maxOf(stageTarget - repsIntoStage, 0)
    val coinsDisplay: String get() = coins.toString()

    companion object {
        val stageNames = listOf(
            "The Foundation", "The Entrance", "The Walls", "The Courtyard", "The Bastion",
            "The Spire", "The Beacon", "The Crown", "The Summit"
        )

        val placeholder = HomeData(
            streak = 0, xp = 0, coins = 0, towerName = "Your Tower", stageNumber = 1, totalStages = 9,
            stageName = "The Foundation", repsIntoStage = 0, stageTarget = 30, sets = 3, repsPerSet = 10,
            estimatedMinutes = 5, xpPerWorkout = 100, rewardName = "Stone", journey = emptyList(), isAllComplete = false
        )
    }
}

/** A workout the server has registered and the arena is running. */
data class ActiveSession(
    val id: String,
    val exercise: Exercise,
    val battleId: String?,
    val startedAt: Instant,
    val completionReps: Int,
    val battleDurationSeconds: Int
) {
    val isBattle: Boolean get() = battleId != null
}

enum class WorkoutEndReason(val raw: String) { Finished("finished"), Interrupted("interrupted"), Timer("timer") }

/** What the results screen shows for a finished workout. */
sealed interface SubmitState {
    data object Saving : SubmitState
    data class Saved(val outcome: WorkoutOutcomeDTO) : SubmitState
    data object Queued : SubmitState
    data class Dropped(val message: String) : SubmitState
}

// MARK: - Battles

enum class BattleOutcome(val title: String) { Victory("Victory"), Defeat("Defeat"), Draw("Draw"), Expired("Expired") }

enum class BattlePhase { Waiting, Active, Completed }

data class BattleResult(val myScore: Int?, val opponentScore: Int?, val outcome: BattleOutcome, val date: Instant)

data class Battle(
    val id: String,
    val code: String,
    val isHost: Boolean,
    val createdDate: Instant,
    val exercise: Exercise,
    val phase: BattlePhase,
    val opponentName: String?,
    val opponentAvatarPath: String?,
    val opponentSubmitted: Boolean,
    val inviteExpiresAt: Instant,
    val deadlineAt: Instant?,
    val myRunStarted: Boolean,
    val mySubmitted: Boolean,
    val myScore: Int?,
    val mySessionId: String?,
    val result: BattleResult?
) {
    val isInvitation: Boolean get() = isHost && phase == BattlePhase.Waiting

    val canStartRun: Boolean
        get() = phase == BattlePhase.Active && !mySubmitted && (deadlineAt?.isAfter(Instant.now()) ?: false)

    val statusText: String
        get() = when (phase) {
            BattlePhase.Waiting -> "Waiting for opponent"
            BattlePhase.Active -> if (mySubmitted) {
                if (opponentSubmitted) "Finalizing result" else "Waiting for ${opponentName ?: "opponent"}"
            } else if (myRunStarted) "Run in progress" else "Your turn"
            BattlePhase.Completed -> result?.outcome?.title ?: "Finished"
        }

    companion object {
        fun from(dto: BattleDTO): Battle {
            val phase = when (dto.status) {
                "waiting" -> BattlePhase.Waiting
                "active" -> BattlePhase.Active
                else -> BattlePhase.Completed
            }
            val created = BackendDates.parse(dto.createdAt) ?: Instant.now()
            val result = if (phase == BattlePhase.Completed) {
                val outcome = when (dto.outcome) {
                    "victory" -> BattleOutcome.Victory
                    "defeat" -> BattleOutcome.Defeat
                    "draw" -> BattleOutcome.Draw
                    else -> BattleOutcome.Expired
                }
                BattleResult(dto.myScore, dto.opponent?.score, outcome, BackendDates.parse(dto.completedAt) ?: created)
            } else null
            return Battle(
                id = dto.id,
                code = dto.code,
                isHost = dto.isHost,
                createdDate = created,
                exercise = Exercise.fromServer(dto.exercise) ?: Exercise.PushUps,
                phase = phase,
                opponentName = dto.opponent?.displayName,
                opponentAvatarPath = dto.opponent?.avatarPath,
                opponentSubmitted = dto.opponent?.submitted ?: false,
                inviteExpiresAt = BackendDates.parse(dto.inviteExpiresAt) ?: created,
                deadlineAt = BackendDates.parse(dto.deadlineAt),
                myRunStarted = dto.myRunStarted,
                mySubmitted = dto.mySubmitted,
                myScore = dto.myScore,
                mySessionId = dto.mySessionId,
                result = result
            )
        }
    }
}

/** Postgres timestamp helpers. */
object BackendDates {
    fun parse(raw: String?): Instant? {
        if (raw.isNullOrBlank()) return null
        return try {
            java.time.OffsetDateTime.parse(raw).toInstant()
        } catch (_: Exception) {
            try {
                Instant.parse(raw)
            } catch (_: Exception) {
                null
            }
        }
    }

    fun dayString(instant: Instant = Instant.now(), zone: java.time.ZoneId = java.time.ZoneId.systemDefault()): String =
        instant.atZone(zone).toLocalDate().toString()
}

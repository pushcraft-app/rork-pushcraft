package com.tinochiwara.pushcraft.data

import android.content.Context
import android.util.Log
import com.tinochiwara.pushcraft.model.ActiveSession
import com.tinochiwara.pushcraft.model.Exercise
import com.tinochiwara.pushcraft.model.RulesDTO
import com.tinochiwara.pushcraft.model.StartSessionDTO
import com.tinochiwara.pushcraft.model.SubmitState
import com.tinochiwara.pushcraft.model.WorkoutEndReason
import com.tinochiwara.pushcraft.model.WorkoutOutcomeDTO
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.io.File
import java.time.Instant
import java.time.ZoneId
import java.util.UUID

/** A workout saved on this phone until the server accepts it. */
@Serializable
data class PendingSession(
    val id: String,
    val userId: String,
    val exercise: String,
    val battleId: String? = null,
    val createdAt: Long,
    val state: String,
    val startedAt: Long? = null,
    val reps: Int = 0,
    val blocks: Int = 0,
    val lastRepAt: Long? = null,
    val updatedAt: Long,
    val endedAt: Long? = null,
    val endReason: String? = null
) {
    companion object {
        const val REGISTERING = "registering"
        const val ACTIVE = "active"
        const val ENDED = "ended"
    }
}

/** User-facing workout start errors. */
class WorkoutException(val kind: Kind) : Exception(kind.message) {
    enum class Kind(val message: String) {
        Offline("Connect to the internet to start. Workouts need a connection to begin."),
        SignedOut("Sign in again to start a workout."),
        BattleClosed("This battle is no longer open."),
        BattleRunUsed("You've already used your run for this battle."),
        Server("Couldn't start the workout. Please try again.")
    }

    companion object {
        fun from(e: Throwable): WorkoutException = WorkoutException(
            when {
                BackendFailure.isOffline(e) -> Kind.Offline
                BackendFailure.hasCode(e, "battle_closed") || BackendFailure.hasCode(e, "battle_not_found") -> Kind.BattleClosed
                BackendFailure.hasCode(e, "battle_run_used") -> Kind.BattleRunUsed
                BackendFailure.hasCode(e, "not_authenticated") -> Kind.SignedOut
                else -> Kind.Server
            }
        )
    }
}

/** Online start, rep checkpoints and duplicate-safe submission. */
class WorkoutService(private val context: Context) {
    private val _pending = MutableStateFlow<List<PendingSession>>(emptyList())
    val pending: StateFlow<List<PendingSession>> = _pending.asStateFlow()
    private val _isSyncing = MutableStateFlow(false)
    val isSyncing: StateFlow<Boolean> = _isSyncing.asStateFlow()

    private var userId: String? = null
    var activeSessionId: String? = null
        private set
    var onAccepted: ((WorkoutOutcomeDTO) -> Unit)? = null

    private val serializer = ListSerializer(PendingSession.serializer())

    fun unsyncedCount(list: List<PendingSession>): Int =
        list.count { it.id != activeSessionId && it.state != PendingSession.REGISTERING }

    fun activate(userId: String) {
        this.userId = userId
        _pending.value = load(userId)
    }

    fun deactivate() {
        userId = null
        activeSessionId = null
        _pending.value = emptyList()
    }

    fun discardAll(userId: String) {
        file(userId).delete()
        if (this.userId == userId) _pending.value = emptyList()
    }

    fun pendingRun(battleId: String): PendingSession? = _pending.value.firstOrNull { it.battleId == battleId }

    suspend fun start(exercise: Exercise, battleId: String?, rules: RulesDTO?): ActiveSession =
        register(prepare(exercise, battleId, rules))

    /**
     * Builds a battle run without telling the server yet, so the player can wait
     * for their friend and leave without using up their single run. Reuses the
     * session ID of a run whose start reply was lost.
     */
    fun prepare(exercise: Exercise, battleId: String?, rules: RulesDTO?): ActiveSession {
        if (userId == null) throw WorkoutException(WorkoutException.Kind.SignedOut)
        val existing = battleId?.let { b -> _pending.value.firstOrNull { it.battleId == b && it.state == PendingSession.REGISTERING } }
        return ActiveSession(
            id = existing?.id ?: UUID.randomUUID().toString(),
            exercise = exercise,
            battleId = battleId,
            startedAt = Instant.now(),
            completionReps = rules?.completionReps ?: 30,
            battleDurationSeconds = rules?.battleDurationSeconds ?: 60
        )
    }

    /** Registers a prepared run with the server. For battles this happens at GO. */
    suspend fun register(session: ActiveSession): ActiveSession {
        val uid = userId ?: throw WorkoutException(WorkoutException.Kind.SignedOut)
        val exercise = session.exercise
        val battleId = session.battleId
        val now = System.currentTimeMillis()
        var record = _pending.value.firstOrNull { it.id == session.id && it.state == PendingSession.REGISTERING }
            ?: PendingSession(
            id = session.id, userId = uid, exercise = exercise.serverValue, battleId = battleId,
            createdAt = now, state = PendingSession.REGISTERING, updatedAt = now
        ).also { upsert(it) }

        try {
            val response = Backend.rpcDecode<StartSessionDTO>(
                "start_workout_session",
                buildJsonObject {
                    put("p_session_id", record.id)
                    put("p_exercise", exercise.serverValue)
                    put("p_timezone", ZoneId.systemDefault().id)
                    if (battleId != null) put("p_battle_id", battleId) else put("p_battle_id", JsonNull)
                    put("p_app_version", Backend.appVersion)
                }
            )
            val started = System.currentTimeMillis()
            record = record.copy(state = PendingSession.ACTIVE, startedAt = started, updatedAt = started)
            upsert(record)
            activeSessionId = record.id
            Log.i("Workout", "Started session ${record.id} (${response.source})")
            return ActiveSession(
                id = record.id,
                exercise = Exercise.fromServer(response.exercise) ?: exercise,
                battleId = battleId,
                startedAt = Instant.ofEpochMilli(started),
                completionReps = session.completionReps,
                battleDurationSeconds = session.battleDurationSeconds
            )
        } catch (e: Exception) {
            val failure = WorkoutException.from(e)
            Log.w("Workout", "Start failed: ${failure.kind}")
            if (battleId == null || failure.kind == WorkoutException.Kind.BattleClosed ||
                failure.kind == WorkoutException.Kind.BattleRunUsed
            ) remove(record.id)
            throw failure
        }
    }

    fun checkpoint(id: String, reps: Int, blocks: Int) {
        val record = _pending.value.firstOrNull { it.id == id } ?: return
        if (record.state != PendingSession.ACTIVE) return
        val now = System.currentTimeMillis()
        upsert(record.copy(reps = reps, blocks = blocks, updatedAt = now, lastRepAt = if (reps != record.reps) now else record.lastRepAt))
    }

    fun abandon(id: String) {
        remove(id)
        if (activeSessionId == id) activeSessionId = null
    }

    suspend fun finish(id: String, reps: Int, blocks: Int, reason: WorkoutEndReason): SubmitState {
        val record = _pending.value.firstOrNull { it.id == id }
            ?: return SubmitState.Dropped("This workout couldn't be found on this phone.")
        val now = System.currentTimeMillis()
        val ended = record.copy(reps = reps, blocks = blocks, state = PendingSession.ENDED, endReason = reason.raw, endedAt = now, updatedAt = now)
        upsert(ended)
        if (activeSessionId == id) activeSessionId = null
        return submit(ended)
    }

    suspend fun retry(id: String): SubmitState {
        val record = _pending.value.firstOrNull { it.id == id } ?: return SubmitState.Dropped("This workout was already saved.")
        return submit(record)
    }

    suspend fun syncPending() {
        if (userId == null || _isSyncing.value) return
        _isSyncing.value = true
        try {
            for (original in _pending.value.filter { it.id != activeSessionId }) {
                var record = original
                when (record.state) {
                    PendingSession.REGISTERING -> {
                        val stale = record.createdAt < System.currentTimeMillis() - 2 * 24 * 3600 * 1000L
                        if (record.battleId == null || stale) remove(record.id)
                        continue
                    }
                    PendingSession.ACTIVE -> {
                        record = record.copy(
                            state = PendingSession.ENDED,
                            endReason = WorkoutEndReason.Interrupted.raw,
                            endedAt = record.lastRepAt ?: record.updatedAt
                        )
                        upsert(record)
                    }
                }
                if (submit(record) is SubmitState.Queued) break
            }
        } finally {
            _isSyncing.value = false
        }
    }

    private suspend fun submit(record: PendingSession): SubmitState {
        return try {
            val outcome = Backend.rpcDecode<WorkoutOutcomeDTO>(
                "complete_workout_session",
                buildJsonObject {
                    put("p_session_id", record.id)
                    put("p_reps", record.reps)
                    put("p_blocks", record.blocks)
                    put("p_end_reason", record.endReason ?: WorkoutEndReason.Finished.raw)
                    val ended = record.endedAt
                    if (ended != null) put("p_client_ended_at", Instant.ofEpochMilli(ended).toString()) else put("p_client_ended_at", JsonNull)
                }
            )
            remove(record.id)
            onAccepted?.invoke(outcome)
            SubmitState.Saved(outcome)
        } catch (e: Exception) {
            when {
                BackendFailure.isOffline(e) -> SubmitState.Queued
                BackendFailure.hasCode(e, "session_expired") -> {
                    remove(record.id)
                    SubmitState.Dropped("This workout is more than 7 days old, so it can no longer be saved.")
                }
                BackendFailure.hasCode(e, "session_not_found") -> {
                    remove(record.id)
                    SubmitState.Dropped("This workout wasn't registered with your account, so it can't be saved.")
                }
                else -> {
                    Log.w("Workout", "Submit failed, will retry: ${e.message}")
                    SubmitState.Queued
                }
            }
        }
    }

    private fun upsert(record: PendingSession) {
        val list = _pending.value.toMutableList()
        val idx = list.indexOfFirst { it.id == record.id }
        if (idx >= 0) list[idx] = record else list.add(record)
        _pending.value = list
        persist()
    }

    private fun remove(id: String) {
        _pending.value = _pending.value.filterNot { it.id == id }
        persist()
    }

    private fun persist() {
        val uid = userId ?: return
        runCatching {
            val f = file(uid)
            f.parentFile?.mkdirs()
            f.writeText(Backend.json.encodeToString(serializer, _pending.value.filter { it.userId == uid }))
        }.onFailure { Log.w("Workout", "Failed to save pending workouts: ${it.message}") }
    }

    private fun load(uid: String): List<PendingSession> = runCatching {
        Backend.json.decodeFromString(serializer, file(uid).readText()).filter { it.userId == uid }
    }.getOrDefault(emptyList())

    private fun file(uid: String): File = File(context.filesDir, "PendingWorkouts/${uid.lowercase()}.json")
}

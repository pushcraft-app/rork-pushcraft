package com.rork.pushcraftandroid.data

import android.util.Log
import com.rork.pushcraftandroid.model.Battle
import com.rork.pushcraftandroid.model.BattleDTO
import com.rork.pushcraftandroid.model.BattlePhase
import com.rork.pushcraftandroid.model.Exercise
import io.github.jan.supabase.realtime.RealtimeChannel
import io.github.jan.supabase.realtime.broadcast
import io.github.jan.supabase.realtime.broadcastFlow
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.realtime
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.put

/** User-facing battle errors. */
class BattleException(message: String) : Exception(message) {
    companion object {
        fun from(e: Throwable): BattleException = BattleException(
            when {
                BackendFailure.isOffline(e) -> "You're offline. Connect to the internet and try again."
                BackendFailure.hasCode(e, "battle_not_found") -> "Battle not found. Check the code and try again."
                BackendFailure.hasCode(e, "own_battle") -> "You can't join your own battle."
                BackendFailure.hasCode(e, "battle_closed") -> "This battle is no longer open to join."
                else -> "Something went wrong. Please try again."
            }
        )
    }
}

/** The signed-in player's battles. */
class BattleStore {
    private val _battles = MutableStateFlow<List<Battle>>(emptyList())
    val battles: StateFlow<List<Battle>> = _battles.asStateFlow()
    private val _hasLoaded = MutableStateFlow(false)
    val hasLoaded: StateFlow<Boolean> = _hasLoaded.asStateFlow()

    fun battle(id: String): Battle? = _battles.value.firstOrNull { it.id == id }

    suspend fun load() {
        try {
            val dtos = Backend.rpcDecode<List<BattleDTO>>("get_my_battles")
            _battles.value = dtos.map(Battle::from)
            _hasLoaded.value = true
        } catch (e: Exception) {
            Log.w("Battles", "Load failed: ${e.message}")
            throw BattleException.from(e)
        }
    }

    suspend fun createInvitation(exercise: Exercise): Battle = mutate {
        Backend.rpcDecode<BattleDTO>("create_battle", buildJsonObject { put("p_exercise", exercise.serverValue) })
    }

    suspend fun join(code: String): Battle = mutate {
        Backend.rpcDecode<BattleDTO>("join_battle", buildJsonObject { put("p_code", code) })
    }

    suspend fun cancel(id: String) {
        try {
            Backend.rpc("cancel_battle", buildJsonObject { put("p_battle_id", id) })
            _battles.update { list -> list.filterNot { it.id == id } }
        } catch (e: Exception) {
            throw BattleException.from(e)
        }
    }

    fun reset() {
        _battles.value = emptyList()
        _hasLoaded.value = false
    }

    private suspend fun mutate(call: suspend () -> BattleDTO): Battle {
        try {
            val battle = Battle.from(call())
            _battles.update { list ->
                val idx = list.indexOfFirst { it.id == battle.id }
                if (idx >= 0) list.toMutableList().also { it[idx] = battle } else listOf(battle) + list
            }
            return battle
        } catch (e: Exception) {
            Log.w("Battles", "Mutation failed: ${e.message}")
            throw BattleException.from(e)
        }
    }
}

val List<Battle>.invitation: Battle? get() = firstOrNull { it.isInvitation }
val List<Battle>.active: List<Battle> get() = filter { it.phase == BattlePhase.Waiting || it.phase == BattlePhase.Active }
val List<Battle>.completed: List<Battle> get() = filter { it.phase == BattlePhase.Completed }

/** Live rep sync over a Supabase Realtime broadcast channel keyed to the battle. */
class BattleLiveSync {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val _opponentReps = MutableStateFlow(0)
    val opponentReps: StateFlow<Int> = _opponentReps.asStateFlow()
    private var channel: RealtimeChannel? = null
    private var listenJob: Job? = null
    private var lastSent = -1

    fun connect(battleId: String) {
        if (channel != null) return
        val ch = Backend.client.channel("battle:${battleId.lowercase()}")
        channel = ch
        val flow = ch.broadcastFlow<JsonObject>(event = "reps")
        listenJob = scope.launch {
            flow.collect { payload ->
                val prim = payload["reps"]?.jsonPrimitive
                val reps = prim?.intOrNull ?: prim?.doubleOrNull?.toInt() ?: return@collect
                _opponentReps.value = maxOf(_opponentReps.value, reps)
            }
        }
        scope.launch { runCatching { ch.subscribe() } }
    }

    fun send(reps: Int) {
        val ch = channel ?: return
        if (reps == lastSent) return
        lastSent = reps
        scope.launch { runCatching { ch.broadcast(event = "reps", message = buildJsonObject { put("reps", reps) }) } }
    }

    fun disconnect() {
        listenJob?.cancel()
        val ch = channel ?: return
        channel = null
        scope.launch { runCatching { Backend.client.realtime.removeChannel(ch) } }
    }
}

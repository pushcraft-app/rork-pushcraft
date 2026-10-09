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
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
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

/**
 * Live link between the two phones in a battle, over a Supabase Realtime
 * broadcast channel keyed to the battle ID. Same protocol as the iPhone app:
 * - `ready` every second while waiting, so the other phone knows we're here.
 * - `start` with `elapsed_ms` since the countdown began, every second once it
 *   started. The host starts it on hearing the guest; the guest aligns to it.
 * - `reps` on every rep and repeated every second.
 * Every message carries the sender's `role` ("host" / "guest").
 */
class BattleLiveSync {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val _opponentReps = MutableStateFlow(0)
    val opponentReps: StateFlow<Int> = _opponentReps.asStateFlow()
    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected.asStateFlow()
    /** Wall-clock millis the shared 5-second countdown began; null while waiting. */
    private val _startAnchor = MutableStateFlow<Long?>(null)
    val startAnchor: StateFlow<Long?> = _startAnchor.asStateFlow()

    private var channel: RealtimeChannel? = null
    private val jobs = mutableListOf<Job>()
    private var isHost = false
    private var battleDuration = 60
    private var myReps = 0
    private var lastSent = -1
    private val logged = mutableSetOf<String>()
    private val role get() = if (isHost) "host" else "guest"

    fun connect(battleId: String, isHost: Boolean, battleDuration: Int) {
        if (channel != null) return
        this.isHost = isHost
        this.battleDuration = battleDuration
        val topic = "battle:${battleId.lowercase()}"
        val ch = Backend.client.channel(topic)
        channel = ch
        Log.i(TAG, "Joining $topic as $role")
        for (event in listOf(EVENT_READY, EVENT_START, EVENT_REPS)) {
            val flow = ch.broadcastFlow<JsonObject>(event = event)
            jobs += scope.launch { flow.collect { handle(event, it) } }
        }
        jobs += scope.launch {
            while (isActive) {
                if (ch.status.value == RealtimeChannel.Status.UNSUBSCRIBED) {
                    runCatching { ch.subscribe() }.onFailure { Log.w(TAG, "Subscribe failed: ${it.message}") }
                }
                val connected = ch.status.value == RealtimeChannel.Status.SUBSCRIBED
                if (connected != _isConnected.value) {
                    _isConnected.value = connected
                    Log.i(TAG, if (connected) "Connected" else "Not connected yet")
                }
                delay(if (connected) 2000 else 1000)
            }
        }
        jobs += scope.launch {
            while (isActive) {
                val anchor = _startAnchor.value
                if (anchor != null) {
                    send(EVENT_START, buildJsonObject { put("elapsed_ms", System.currentTimeMillis() - anchor) })
                    lastSent = myReps
                    send(EVENT_REPS, buildJsonObject { put("reps", myReps) })
                } else {
                    send(EVENT_READY, buildJsonObject { })
                }
                delay(1000)
            }
        }
    }

    /** Starts the countdown without an opponent (they already played their run). */
    fun beginSolo() {
        if (_startAnchor.value != null) return
        _startAnchor.value = System.currentTimeMillis()
        Log.i(TAG, "Opponent already played — starting solo")
    }

    /** Records the local rep count and sends it right away when it changed. */
    fun update(reps: Int) {
        myReps = reps
        if (_startAnchor.value == null || reps == lastSent) return
        lastSent = reps
        send(EVENT_REPS, buildJsonObject { put("reps", reps) })
        Log.i(TAG, "Sent reps $reps")
    }

    fun disconnect() {
        jobs.forEach { it.cancel() }
        jobs.clear()
        _isConnected.value = false
        val ch = channel ?: return
        channel = null
        CoroutineScope(Dispatchers.IO).launch { runCatching { Backend.client.realtime.removeChannel(ch) } }
    }

    private fun send(event: String, fields: JsonObject) {
        val ch = channel ?: return
        if (ch.status.value != RealtimeChannel.Status.SUBSCRIBED) return
        val message = JsonObject(fields + ("role" to JsonPrimitive(role)))
        scope.launch {
            runCatching { ch.broadcast(event = event, message = message) }
                .onFailure { Log.w(TAG, "Send $event failed: ${it.message}") }
        }
    }

    private fun handle(event: String, message: JsonObject) {
        // Accept both the bare payload and the full {type, event, payload} envelope.
        val body = (message["payload"] as? JsonObject) ?: message
        if ((body["role"] as? JsonPrimitive)?.contentOrNull == role) return
        if (logged.add(event)) Log.i(TAG, "First '$event' received from opponent")
        when (event) {
            EVENT_READY -> if (isHost && _startAnchor.value == null) {
                _startAnchor.value = System.currentTimeMillis()
                Log.i(TAG, "Both players here — host starts the countdown")
            }
            EVENT_START -> {
                val elapsed = number(body["elapsed_ms"])?.toLong() ?: return
                val now = System.currentTimeMillis()
                val peerAnchor = now - maxOf(0L, elapsed)
                val current = _startAnchor.value
                if (current != null) {
                    // Only the guest re-aligns, and only before GO.
                    val beforeGo = now < current + COUNTDOWN_MS
                    if (isHost || !beforeGo || kotlin.math.abs(current - peerAnchor) <= 750) return
                } else if (elapsed >= COUNTDOWN_MS + (battleDuration - 5) * 1000L) {
                    return
                }
                _startAnchor.value = peerAnchor
                Log.i(TAG, "Countdown synced to opponent ($elapsed ms in)")
            }
            EVENT_REPS -> {
                val reps = number(body["reps"])?.toInt() ?: return
                if (reps > _opponentReps.value) {
                    _opponentReps.value = reps
                    Log.i(TAG, "Opponent reps $reps")
                }
            }
        }
    }

    private fun number(e: JsonElement?): Double? {
        val p = e as? JsonPrimitive ?: return null
        return p.doubleOrNull ?: p.contentOrNull?.toDoubleOrNull()
    }

    companion object {
        const val COUNTDOWN_MS = 5000L
        private const val TAG = "BattleLive"
        private const val EVENT_READY = "ready"
        private const val EVENT_START = "start"
        private const val EVENT_REPS = "reps"
    }
}

package com.tinochiwara.pushcraft.data

import android.content.Context
import android.util.Log
import com.tinochiwara.pushcraft.model.OnboardingAnswers
import io.github.jan.supabase.auth.SignOutScope
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.Apple
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.status.SessionStatus
import io.github.jan.supabase.functions.functions
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/** App-level session: Supabase auth state plus the per-account stores. */
class AppState(private val context: Context) {
    enum class Phase { Loading, SignedOut, SignedIn }

    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val _phase = MutableStateFlow(Phase.Loading)
    val phase: StateFlow<Phase> = _phase.asStateFlow()
    private val _email = MutableStateFlow<String?>(null)
    val email: StateFlow<String?> = _email.asStateFlow()
    private val _isAuthenticating = MutableStateFlow(false)
    val isAuthenticating: StateFlow<Boolean> = _isAuthenticating.asStateFlow()
    val authError = MutableStateFlow<String?>(null)

    var userId: String? = null
        private set

    val progress = ProgressStore()
    val battles = BattleStore()
    val workouts = WorkoutService(context)
    val store = StoreService()
    val onboarding = OnboardingModel()

    private var started = false

    fun start() {
        if (started) return
        started = true
        store.start()
        workouts.onAccepted = { outcome ->
            scope.launch {
                progress.load()
                if (outcome.battleId != null) runCatching { battles.load() }
            }
        }
        scope.launch {
            Backend.client.auth.sessionStatus.collect { status ->
                when (status) {
                    is SessionStatus.Authenticated -> {
                        val user = status.session.user ?: Backend.client.auth.currentUserOrNull()
                        if (user != null) handleSignedIn(user.id, user.email)
                    }
                    is SessionStatus.NotAuthenticated -> handleSignedOut()
                    is SessionStatus.RefreshFailure -> {
                        // Offline refresh: keep the cached session if we already had one.
                        if (_phase.value == Phase.Loading) {
                            val user = Backend.client.auth.currentUserOrNull()
                            if (user != null) handleSignedIn(user.id, user.email) else handleSignedOut()
                        }
                    }
                    else -> Unit
                }
            }
        }
    }

    private fun handleSignedIn(id: String, email: String?) {
        val isNewUser = userId != id
        if (isNewUser) onboarding.beginSetupIfNeeded()
        userId = id
        _email.value = email
        _phase.value = Phase.SignedIn
        _isAuthenticating.value = false
        if (isNewUser) {
            scope.launch { store.logIn(id) }
            scope.launch { bootstrap(id) }
        }
    }

    private fun handleSignedOut() {
        val wasSignedIn = _phase.value == Phase.SignedIn
        _phase.value = Phase.SignedOut
        _isAuthenticating.value = false
        userId = null
        _email.value = null
        progress.reset()
        battles.reset()
        workouts.deactivate()
        Reminders.clear(context)
        if (wasSignedIn) {
            onboarding.reset()
            scope.launch { store.logOut() }
        }
    }

    private suspend fun bootstrap(id: String) {
        workouts.activate(id)
        OnboardingSync.flushPending(id)
        progress.load()
        runCatching { battles.load() }
        workouts.syncPending()
        scheduleReminders()
    }

    fun scheduleReminders() {
        val d = progress.dashboard.value
        Reminders.schedule(context, Progress.hasStreakToday(d), Progress.displayStreak(d))
    }

    suspend fun completeOnboardingSave() {
        val id = userId ?: return
        OnboardingSync.save(onboarding.makeAnswers(), id)
        progress.load()
    }

    suspend fun refresh() {
        if (_phase.value != Phase.SignedIn) return
        store.refresh()
        workouts.syncPending()
        progress.load()
        runCatching { battles.load() }
    }

    // MARK: - Sign-in (Supabase OAuth via Custom Tabs)

    fun signInWithGoogle() = oauth("Google") { Backend.client.auth.signInWith(Google) }
    fun signInWithApple() = oauth("Apple") { Backend.client.auth.signInWith(Apple) }

    private fun oauth(name: String, block: suspend () -> Unit) {
        scope.launch {
            _isAuthenticating.value = true
            try {
                block()
            } catch (e: Exception) {
                Log.w("Auth", "$name sign in failed: ${e.message}")
                onboarding.awaitingSignUp = false
                authError.value = "Couldn't sign in with $name. Please try again."
                _isAuthenticating.value = false
            }
            // The browser returns via deep link; release the spinner if the user backs out.
            kotlinx.coroutines.delay(1500)
            if (_phase.value != Phase.SignedIn) _isAuthenticating.value = false
        }
    }

    suspend fun signOut() {
        runCatching { Backend.client.auth.signOut() }
            .onFailure { Log.w("Auth", "Remote sign out failed: ${it.message}") }
    }

    suspend fun deleteAccount() {
        Backend.client.functions.invoke("delete-account")
        userId?.let { workouts.discardAll(it) }
        runCatching { Backend.client.auth.signOut(SignOutScope.LOCAL) }
    }
}

/** Saves onboarding answers, keeping a copy until the server confirms. */
object OnboardingSync {
    private fun key(userId: String) = "onboarding.pending.${userId.lowercase()}"

    suspend fun save(answers: OnboardingAnswers, userId: String): Boolean {
        AppPreferences.putString(key(userId), Backend.json.encodeToString(OnboardingAnswers.serializer(), answers))
        return send(answers, userId)
    }

    suspend fun flushPending(userId: String) {
        val raw = AppPreferences.getString(key(userId)) ?: return
        val answers = runCatching { Backend.json.decodeFromString(OnboardingAnswers.serializer(), raw) }.getOrNull() ?: return
        send(answers, userId)
    }

    private suspend fun send(answers: OnboardingAnswers, userId: String): Boolean = try {
        Backend.rpc("save_onboarding", buildJsonObject {
            put("p_answers", Backend.json.encodeToJsonElement(OnboardingAnswers.serializer(), answers))
        })
        AppPreferences.putString(key(userId), null)
        true
    } catch (e: Exception) {
        Log.w("Onboarding", "Save failed, will retry: ${e.message}")
        false
    }
}

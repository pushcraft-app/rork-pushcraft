package com.rork.pushcraftandroid.data

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import com.rork.pushcraftandroid.model.BackendDates
import com.rork.pushcraftandroid.model.DashboardDTO
import com.rork.pushcraftandroid.model.HomeData
import com.rork.pushcraftandroid.model.JourneyStage
import com.rork.pushcraftandroid.model.StageState
import com.rork.pushcraftandroid.model.Tower
import com.rork.pushcraftandroid.model.TowerStatus
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.storage.storage
import io.ktor.http.ContentType
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.io.ByteArrayOutputStream
import java.time.Instant
import java.time.temporal.ChronoUnit

/** The signed-in user's profile, stats and tower progress from the server. */
class ProgressStore {
    private val _dashboard = MutableStateFlow<DashboardDTO?>(null)
    val dashboard: StateFlow<DashboardDTO?> = _dashboard.asStateFlow()

    private val _avatar = MutableStateFlow<ByteArray?>(null)
    val avatar: StateFlow<ByteArray?> = _avatar.asStateFlow()

    private val _loadError = MutableStateFlow<String?>(null)
    val loadError: StateFlow<String?> = _loadError.asStateFlow()

    private var loadedAvatarPath: String? = null

    suspend fun load() {
        try {
            _dashboard.value = Backend.rpcDecode<DashboardDTO>("get_my_dashboard")
            _loadError.value = null
            loadAvatarIfNeeded()
        } catch (e: Exception) {
            Log.w("Progress", "Dashboard load failed: ${e.message}")
            _loadError.value = if (BackendFailure.isOffline(e)) {
                "You're offline. Showing your last synced progress."
            } else "Couldn't load your progress."
        }
    }

    fun reset() {
        _dashboard.value = null
        _avatar.value = null
        loadedAvatarPath = null
        _loadError.value = null
    }

    private suspend fun loadAvatarIfNeeded() {
        val path = _dashboard.value?.profile?.avatarPath
        if (path == loadedAvatarPath) return
        if (path == null) {
            _avatar.value = null
            loadedAvatarPath = null
            return
        }
        try {
            _avatar.value = Backend.client.storage.from("avatars").downloadAuthenticated(path)
            loadedAvatarPath = path
        } catch (e: Exception) {
            Log.w("Progress", "Avatar download failed: ${e.message}")
        }
    }

    /** Saves the display name and, if changed, uploads or removes the photo. */
    suspend fun updateProfile(name: String, photo: ByteArray?, photoChanged: Boolean) {
        val profile = _dashboard.value?.profile ?: return
        val folder = profile.id.lowercase()
        val oldPath = profile.avatarPath
        var newPath = oldPath
        var newAvatar = _avatar.value
        val bucket = Backend.client.storage.from("avatars")

        if (photoChanged) {
            val jpeg = photo?.let { prepareAvatar(it) }
            if (jpeg != null) {
                val path = "$folder/avatar-${Instant.now().epochSecond}.jpg"
                bucket.upload(path, jpeg) {
                    upsert = true
                    contentType = ContentType.Image.JPEG
                }
                newPath = path
                newAvatar = jpeg
            } else {
                newPath = null
                newAvatar = null
            }
        }

        Backend.client.from("profiles").update({
            set("display_name", name)
            set<String?>("avatar_path", newPath)
        }) {
            filter { eq("id", folder) }
        }

        if (photoChanged && oldPath != null && oldPath != newPath) {
            runCatching { bucket.delete(listOf(oldPath)) }
        }
        _avatar.value = newAvatar
        loadedAvatarPath = newPath
        load()
    }

    private fun prepareAvatar(data: ByteArray): ByteArray? {
        val bitmap = BitmapFactory.decodeByteArray(data, 0, data.size) ?: return null
        val scale = minOf(1f, 512f / maxOf(bitmap.width, bitmap.height))
        val resized = Bitmap.createScaledBitmap(
            bitmap, (bitmap.width * scale).toInt().coerceAtLeast(1), (bitmap.height * scale).toInt().coerceAtLeast(1), true
        )
        val out = ByteArrayOutputStream()
        resized.compress(Bitmap.CompressFormat.JPEG, 82, out)
        return out.toByteArray()
    }
}

/** Pure derivations from the dashboard, shared by every screen. */
object Progress {
    fun displayStreak(d: DashboardDTO?): Int {
        val stats = d?.stats ?: return 0
        val last = stats.lastStreakDate ?: return 0
        val today = BackendDates.dayString()
        val yesterday = BackendDates.dayString(Instant.now().minus(1, ChronoUnit.DAYS))
        return if (last >= yesterday || last == today) stats.currentStreak else 0
    }

    fun hasStreakToday(d: DashboardDTO?): Boolean = d?.stats?.lastStreakDate == BackendDates.dayString()

    fun homeData(d: DashboardDTO?): HomeData {
        d ?: return HomeData.placeholder
        val active = d.progress.firstOrNull { it.status == "in_progress" }
        val ordered = d.towers.sortedBy { it.sortOrder }
        val lastCompleted = ordered.lastOrNull { t -> d.progress.any { it.towerId == t.id && it.status == "completed" } }
        val tower = ordered.firstOrNull { it.id == active?.towerId } ?: lastCompleted ?: ordered.firstOrNull()
            ?: return HomeData.placeholder
        return homeData(d, tower.id)
    }

    fun homeData(d: DashboardDTO?, towerId: String): HomeData {
        d ?: return HomeData.placeholder
        val tower = d.towers.firstOrNull { it.id == towerId }
        val stages = d.stages.filter { it.towerId == towerId }.sortedBy { it.stageNumber }
        val row = d.progress.firstOrNull { it.towerId == towerId }
        val isComplete = row?.status == "completed"
        val currentStage = if (isComplete) stages.size else (row?.currentStage ?: 1)
        val stageTarget = if (isComplete) stages.lastOrNull()?.repsRequired ?: 0
        else row?.stageTarget ?: stages.lastOrNull()?.repsRequired ?: 0
        val repsIntoStage = if (isComplete) stageTarget else (row?.repsIntoStage ?: 0)
        val stageName = stages.firstOrNull { it.stageNumber == currentStage }?.name.orEmpty()
        val journey = stages.map { s ->
            when {
                isComplete || s.stageNumber < currentStage ->
                    JourneyStage(s.stageNumber, s.name, StageState.Completed, s.repsRequired, s.repsRequired)
                s.stageNumber == currentStage ->
                    JourneyStage(s.stageNumber, s.name, StageState.Current, stageTarget, repsIntoStage)
                else -> JourneyStage(s.stageNumber, s.name, StageState.Locked, s.repsRequired, 0)
            }
        }
        val completion = d.rules.completionReps
        return HomeData(
            streak = displayStreak(d),
            xp = d.stats.xpTotal,
            coins = d.stats.coinsBalance,
            towerName = tower?.name ?: "Your Tower",
            stageNumber = currentStage,
            totalStages = maxOf(stages.size, 1),
            stageName = stageName,
            repsIntoStage = repsIntoStage,
            stageTarget = stageTarget,
            sets = 3,
            repsPerSet = maxOf(completion / 3, 1),
            estimatedMinutes = 5,
            xpPerWorkout = d.rules.xpPerCompleted,
            rewardName = "Stone",
            journey = journey,
            isAllComplete = isComplete
        )
    }

    fun towers(d: DashboardDTO?): List<Tower> {
        d ?: return emptyList()
        val ordered = d.towers.sortedBy { it.sortOrder }
        return ordered.mapIndexed { index, def ->
            val stages = d.stages.filter { it.towerId == def.id }.sortedBy { it.stageNumber }
            val totalReps = stages.sumOf { it.repsRequired }
            val row = d.progress.firstOrNull { it.towerId == def.id }
            var stageFraction = 0.0
            val (status, progress, currentStage) = when (row?.status) {
                "completed" -> Triple(TowerStatus.Completed, 1.0, stages.size)
                "in_progress" -> {
                    val done = stages.filter { it.stageNumber < row.currentStage }.sumOf { it.repsRequired } + row.repsIntoStage
                    if (row.stageTarget > 0) stageFraction = (row.repsIntoStage.toDouble() / row.stageTarget).coerceIn(0.0, 1.0)
                    Triple(
                        TowerStatus.InProgress,
                        if (totalReps == 0) 0.0 else minOf(done.toDouble() / totalReps, 1.0),
                        row.currentStage
                    )
                }
                else -> Triple(TowerStatus.Locked, 0.0, 0)
            }
            Tower(
                id = def.id,
                name = def.name,
                status = status,
                currentStage = currentStage,
                totalStages = stages.size,
                totalReps = totalReps,
                progress = progress,
                stageFraction = stageFraction,
                unlockedAfter = if (index > 0) ordered[index - 1].name else null
            )
        }
    }

    fun currentTowerId(towers: List<Tower>): String? =
        towers.firstOrNull { it.status == TowerStatus.InProgress }?.id
            ?: towers.lastOrNull { it.status == TowerStatus.Completed }?.id
}

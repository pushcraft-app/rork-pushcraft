package com.rork.pushcraftandroid.data

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

/** On-device preferences for reminders, haptics and sound. */
object AppPreferences {
    private lateinit var prefs: SharedPreferences

    private val _notifications = MutableStateFlow(true)
    private val _haptics = MutableStateFlow(true)
    private val _sound = MutableStateFlow(true)
    val notificationsFlow: StateFlow<Boolean> = _notifications.asStateFlow()
    val hapticsFlow: StateFlow<Boolean> = _haptics.asStateFlow()
    val soundFlow: StateFlow<Boolean> = _sound.asStateFlow()

    fun init(context: Context) {
        prefs = context.getSharedPreferences("pushcraft.prefs", Context.MODE_PRIVATE)
        _notifications.value = prefs.getBoolean("prefs.notifications", true)
        _haptics.value = prefs.getBoolean("prefs.haptics", true)
        _sound.value = prefs.getBoolean("prefs.sound", true)
    }

    var notificationsEnabled: Boolean
        get() = _notifications.value
        set(value) { _notifications.value = value; prefs.edit().putBoolean("prefs.notifications", value).apply() }

    var hapticsEnabled: Boolean
        get() = _haptics.value
        set(value) { _haptics.value = value; prefs.edit().putBoolean("prefs.haptics", value).apply() }

    var soundEnabled: Boolean
        get() = _sound.value
        set(value) { _sound.value = value; prefs.edit().putBoolean("prefs.sound", value).apply() }

    /** Reminder time in minutes after midnight. */
    var reminderMinutes: Int
        get() = prefs.getInt("prefs.reminderMinutes", 19 * 60)
        set(value) = prefs.edit().putInt("prefs.reminderMinutes", value).apply()

    /** ISO weekdays to remind on. Empty means every day. */
    var reminderDays: List<Int>
        get() = prefs.getString("prefs.reminderDays", "").orEmpty().split(",").mapNotNull { it.toIntOrNull() }
        set(value) = prefs.edit().putString("prefs.reminderDays", value.joinToString(",")).apply()

    var hasSeenProgressTip: Boolean
        get() = prefs.getBoolean("prefs.progressTip", false)
        set(value) = prefs.edit().putBoolean("prefs.progressTip", value).apply()

    val reminderTimeText: String
        get() = LocalTime.of(reminderMinutes / 60, reminderMinutes % 60)
            .format(DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT))

    fun getString(key: String): String? = prefs.getString(key, null)
    fun putString(key: String, value: String?) {
        if (value == null) prefs.edit().remove(key).apply() else prefs.edit().putString(key, value).apply()
    }
}

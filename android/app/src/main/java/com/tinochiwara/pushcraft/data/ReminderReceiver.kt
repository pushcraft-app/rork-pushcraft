package com.tinochiwara.pushcraft.data

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.tinochiwara.pushcraft.MainActivity
import com.tinochiwara.pushcraft.R
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

/** Posts a scheduled streak reminder. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra("title") ?: "Your tower is waiting"
        val body = intent.getStringExtra("body") ?: "A quick 30-rep workout keeps your tower growing."
        Reminders.post(context, title, body)
    }
}

/** Local build reminders scheduled on the phone at the chosen time and days. */
object Reminders {
    private const val CHANNEL = "streak_reminders"
    private const val COUNT = 14

    fun hasPermission(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun ensureChannel(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL) == null) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Build reminders", NotificationManager.IMPORTANCE_DEFAULT)
            )
        }
    }

    fun post(context: Context, title: String, body: String) {
        if (!hasPermission(context)) return
        ensureChannel(context)
        val open = PendingIntent.getActivity(
            context, 0, Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(4242, notification)
        } catch (_: SecurityException) {
        }
    }

    private fun pending(context: Context, index: Int, title: String = "", body: String = ""): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java)
            .putExtra("title", title)
            .putExtra("body", body)
        return PendingIntent.getBroadcast(
            context, 7000 + index, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }

    fun clear(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        for (i in 0 until COUNT) alarms.cancel(pending(context, i))
    }

    /** Schedules reminders for the next two weeks on the chosen days. */
    fun schedule(context: Context, doneToday: Boolean, streak: Int) {
        clear(context)
        if (!AppPreferences.notificationsEnabled || !hasPermission(context)) return
        val alarms = context.getSystemService(AlarmManager::class.java)
        val zone = ZoneId.systemDefault()
        val now = LocalDateTime.now()
        val minutes = AppPreferences.reminderMinutes
        val days = AppPreferences.reminderDays.toSet()
        val body = if (streak > 0) {
            "Finish a 30-rep workout today to keep your $streak-day streak."
        } else {
            "A quick 30-rep workout keeps your tower growing."
        }
        for (offset in 0 until COUNT) {
            if (offset == 0 && doneToday) continue
            val day = LocalDate.now().plusDays(offset.toLong())
            val fire = day.atTime(minutes / 60, minutes % 60)
            if (!fire.isAfter(now)) continue
            if (days.isNotEmpty() && day.dayOfWeek.value !in days) continue
            val millis = fire.atZone(zone).toInstant().toEpochMilli()
            alarms.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP, millis,
                pending(context, offset, "Your tower is waiting", body)
            )
        }
    }
}

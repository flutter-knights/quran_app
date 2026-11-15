package com.example.quran_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

object AlertChannels {

    const val ALERT_TONE = AlertPlanner.ALERT_TONE_CHANNEL
    const val ALERT_VIBRATE = AlertPlanner.ALERT_VIBRATE_CHANNEL
    const val ALERT_SILENT = AlertPlanner.ALERT_SILENT_CHANNEL
    const val REMINDER_TONE = AlertPlanner.REMINDER_TONE_CHANNEL
    const val REMINDER_VIBRATE = AlertPlanner.REMINDER_VIBRATE_CHANNEL
    const val REMINDER_SILENT = AlertPlanner.REMINDER_SILENT_CHANNEL
    const val PLAYBACK = AlertPlanner.PLAYBACK_CHANNEL

    fun ensureAll(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val existing = manager.notificationChannels.map { it.id }.toSet()
        val channels = listOf(
            channel(context, ALERT_TONE, R.string.channel_alert_tone, NotificationManager.IMPORTANCE_HIGH, sound = true, vibrate = false),
            channel(context, ALERT_VIBRATE, R.string.channel_alert_vibrate, NotificationManager.IMPORTANCE_HIGH, sound = false, vibrate = true),
            channel(context, ALERT_SILENT, R.string.channel_alert_silent, NotificationManager.IMPORTANCE_DEFAULT, sound = false, vibrate = false),
            channel(context, REMINDER_TONE, R.string.channel_reminder_tone, NotificationManager.IMPORTANCE_DEFAULT, sound = true, vibrate = false),
            channel(context, REMINDER_VIBRATE, R.string.reminder_channel_name, NotificationManager.IMPORTANCE_DEFAULT, sound = false, vibrate = true).apply {
                description = context.getString(R.string.reminder_channel_description)
                vibrationPattern = longArrayOf(0L, 200L)
            },
            channel(context, REMINDER_SILENT, R.string.channel_reminder_silent, NotificationManager.IMPORTANCE_LOW, sound = false, vibrate = false),
        ).filter { it.id !in existing }
        if (channels.isNotEmpty()) manager.createNotificationChannels(channels)
    }

    fun isBlocked(context: Context, id: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val manager = context.getSystemService(NotificationManager::class.java) ?: return false
        return manager.getNotificationChannel(id)?.importance == NotificationManager.IMPORTANCE_NONE
    }

    private fun channel(context: Context, id: String, nameRes: Int, importance: Int, sound: Boolean, vibrate: Boolean) =
        NotificationChannel(id, context.getString(nameRes), importance).apply {
            setShowBadge(false)
            enableVibration(vibrate)
            if (!sound) setSound(null, null)
        }
}

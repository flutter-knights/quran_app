package com.example.quran_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

object AlertChannels {

    const val ALERT_SILENT = "prayer_alert_silent_v2"

    fun ensureAlertSilent(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(ALERT_SILENT) != null) return
        val channel = NotificationChannel(
            ALERT_SILENT,
            context.getString(R.string.channel_alert_silent),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        manager.createNotificationChannel(channel)
    }
}

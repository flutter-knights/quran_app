package com.example.quran_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Fires at T-N before a prayer. Posts a single notification with the system's
 * built-in countdown chronometer (`setUsesChronometer + setChronometerCountDown`).
 *
 * The OS handles the per-second visual countdown; we do no polling.
 *
 * The matching reminder notification is cancelled by [AdhanAlarmReceiver]
 * when the actual adhan alarm fires at T-0.
 */
class PrayerReminderReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        val prayer = intent?.getStringExtra(EXTRA_PRAYER) ?: return
        val prayerTimestampMs = intent.getLongExtra(EXTRA_PRAYER_TIMESTAMP_MS, 0L)
        val notifId = intent.getIntExtra(
            EXTRA_NOTIFICATION_ID,
            PrayerReminderIds.notificationIdByPrayer[prayer] ?: return,
        )
        val localeCode = intent.getStringExtra(EXTRA_LOCALE) ?: "en"
        val offsetMinutes = intent.getIntExtra(EXTRA_OFFSET_MINUTES, 0)

        Log.i(TAG, "onReceive prayer=$prayer offset=${offsetMinutes}m " +
            "prayerAt=$prayerTimestampMs locale=$localeCode")

        ensureChannel(context)
        val notif = buildNotification(
            context, prayer, prayerTimestampMs, localeCode,
        )
        NotificationManagerCompat.from(context).notify(notifId, notif)
    }

    private fun buildNotification(
        context: Context,
        prayer: String,
        prayerTimestampMs: Long,
        localeCode: String,
    ): android.app.Notification {
        val ctx = localizedContext(context, localeCode)

        val titleResId = ctx.resources.getIdentifier(
            "reminder_title_$prayer", "string", context.packageName,
        ).let { if (it != 0) it else R.string.adhan_title_fajr }
        val bodyResId = ctx.resources.getIdentifier(
            "reminder_body_$prayer", "string", context.packageName,
        ).let { if (it != 0) it else R.string.adhan_body_fajr }
        val title = ctx.getString(titleResId)
        val body = ctx.getString(bodyResId)

        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val openPI = PendingIntent.getActivity(
            context, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setWhen(prayerTimestampMs)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setShowWhen(true)
            .setOnlyAlertOnce(true)
            .setOngoing(false)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setSound(null)
            .setVibrate(longArrayOf(0L, 200L))
            .setContentIntent(openPI)
            .build()
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
            ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val name = context.getString(R.string.reminder_channel_name)
        val channel = NotificationChannel(
            CHANNEL_ID, name, NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = context.getString(R.string.reminder_channel_description)
            setShowBadge(false)
            enableVibration(true)
            vibrationPattern = longArrayOf(0L, 200L)
            setSound(null, null)
        }
        manager.createNotificationChannel(channel)
    }

    private fun localizedContext(context: Context, localeCode: String): Context {
        val locale = java.util.Locale(localeCode)
        val config = Configuration(context.resources.configuration)
        config.setLocale(locale)
        return context.createConfigurationContext(config)
    }

    companion object {
        private const val TAG = "PrayerReminderRx"
        const val CHANNEL_ID = "prayer_reminder_channel"

        const val EXTRA_PRAYER = "prayer"
        const val EXTRA_PRAYER_TIMESTAMP_MS = "prayer_ts_ms"
        const val EXTRA_NOTIFICATION_ID = "notif_id"
        const val EXTRA_LOCALE = "locale"
        const val EXTRA_OFFSET_MINUTES = "offset_minutes"
    }
}

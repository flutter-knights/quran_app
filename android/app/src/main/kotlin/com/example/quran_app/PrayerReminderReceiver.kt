package com.example.quran_app

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.util.TimeZone

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
        val reminderSound = intent.getStringExtra(EXTRA_REMINDER_SOUND) ?: "vibrate"
        val now = System.currentTimeMillis()

        Log.i(TAG, "onReceive prayer=$prayer offset=${offsetMinutes}m " +
            "prayerAt=$prayerTimestampMs locale=$localeCode sound=$reminderSound")

        if (prayerTimestampMs <= now) {
            Log.i(TAG, "onReceive: $prayer already passed, skipping reminder")
            return
        }

        AlertChannels.ensureAll(context)
        val label = AlertPlanner.labelKey(prayer, prayerTimestampMs, TimeZone.getDefault())
        val notif = buildNotification(
            context, label, prayerTimestampMs, localeCode, reminderSound, prayerTimestampMs - now,
        )
        NotificationManagerCompat.from(context).notify(notifId, notif)
    }

    private fun buildNotification(
        context: Context,
        label: String,
        prayerTimestampMs: Long,
        localeCode: String,
        reminderSound: String,
        timeoutMs: Long,
    ): android.app.Notification {
        val ctx = localizedContext(context, localeCode)

        val titleResId = ctx.resources.getIdentifier(
            "reminder_title_$label", "string", context.packageName,
        ).let { if (it != 0) it else R.string.adhan_title_fajr }
        val bodyResId = ctx.resources.getIdentifier(
            "reminder_body_$label", "string", context.packageName,
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

        val channel = AlertPlanner.reminderChannel(reminderSound)
        val builder = NotificationCompat.Builder(context, channel)
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
            .setTimeoutAfter(timeoutMs)
            .setContentIntent(openPI)
        when (channel) {
            AlertChannels.REMINDER_TONE -> builder.setDefaults(NotificationCompat.DEFAULT_SOUND)
            AlertChannels.REMINDER_SILENT -> builder.setSound(null).setPriority(NotificationCompat.PRIORITY_LOW)
            else -> builder.setSound(null).setVibrate(longArrayOf(0L, 200L))
        }
        return builder.build()
    }

    companion object {
        private const val TAG = "PrayerReminderRx"
        const val CHANNEL_ID = AlertPlanner.REMINDER_VIBRATE_CHANNEL

        const val EXTRA_PRAYER = "prayer"
        const val EXTRA_PRAYER_TIMESTAMP_MS = "prayer_ts_ms"
        const val EXTRA_NOTIFICATION_ID = "notif_id"
        const val EXTRA_LOCALE = "locale"
        const val EXTRA_OFFSET_MINUTES = "offset_minutes"
        const val EXTRA_REMINDER_SOUND = "reminderSound"
    }
}

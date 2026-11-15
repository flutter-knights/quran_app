package com.example.quran_app

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.text.NumberFormat
import java.util.Locale
import java.util.TimeZone

class AdhanAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        AlertStore.post(context) { ctx ->
            try {
                handle(ctx, intent)
            } finally {
                pending.finish()
            }
        }
    }

    private fun handle(context: Context, intent: Intent) {
        val prayer = intent.getStringExtra(EXTRA_PRAYER) ?: return
        val localeCode = intent.getStringExtra(EXTRA_LOCALE) ?: "en"
        if (intent.getBooleanExtra(EXTRA_TEST, false)) {
            deliver(context, prayer, localeCode, intent.getStringExtra(EXTRA_SOUND) ?: "adhan", intent.getBooleanExtra(EXTRA_RING_IN_SILENT, false))
            return
        }
        try {
            routeFire(context, intent, prayer, localeCode)
        } finally {
            AdhanScheduler.rearmFromSnapshot(context)
        }
    }

    private fun routeFire(context: Context, intent: Intent, prayer: String, localeCode: String) {
        val nowWall = System.currentTimeMillis()
        val nowElapsed = SystemClock.elapsedRealtime()
        val legacy = !intent.hasExtra(EXTRA_SOUND)
        val sound = if (legacy) "adhan" else intent.getStringExtra(EXTRA_SOUND) ?: "adhan"
        val ringInSilent = legacy || intent.getBooleanExtra(EXTRA_RING_IN_SILENT, false)
        val triggerAt = intent.getLongExtra(EXTRA_TRIGGER_AT, 0L).takeIf { it > 0L } ?: nowWall
        val key = intent.getStringExtra(EXTRA_KEY) ?: AlertPlanner.keyFor(triggerAt, prayer, TimeZone.getDefault())
        val route = AlertPlanner.route(
            NotificationManagerCompat.from(context).areNotificationsEnabled(),
            false,
            nowWall,
            nowElapsed,
            triggerAt,
            intent.longOrNull(EXTRA_NEXT_AT),
            intent.longOrNull(EXTRA_ARMED_AT),
            intent.longOrNull(EXTRA_ARMED_ELAPSED),
        )
        Log.i(TAG, "onReceive $key route=$route legacy=$legacy sound=$sound")
        when (route) {
            AlertPlanner.Route.SKIP -> AlertStore.writeRecord(context, key, AlertPlanner.Record(AlertPlanner.Outcome.SKIPPED, triggerAt))
            AlertPlanner.Route.MISSED -> AlertStore.writeRecord(context, key, AlertPlanner.Record(AlertPlanner.Outcome.MISSED, triggerAt))
            AlertPlanner.Route.LATE -> {
                postLate(context, prayer, localeCode, ((nowWall - triggerAt) / 60_000L).toInt())
                AlertStore.writeRecord(context, key, AlertPlanner.Record(AlertPlanner.Outcome.LATE, triggerAt))
            }
            AlertPlanner.Route.DELIVER -> {
                AlertStore.writeRecord(context, key, AlertPlanner.Record(AlertPlanner.Outcome.FIRED, triggerAt))
                PrayerReminderIds.notificationIdByPrayer[prayer]?.let { NotificationManagerCompat.from(context).cancel(it) }
                deliver(context, prayer, localeCode, sound, ringInSilent)
            }
        }
    }

    private fun Intent.longOrNull(name: String) = if (hasExtra(name)) getLongExtra(name, 0L) else null

    companion object {
        private const val TAG = "AdhanReceiver"
        const val LATE_NOTIFICATION_ID = 210
        const val EXTRA_PRAYER = "prayer"
        const val EXTRA_CLIP = "clip"
        const val EXTRA_LOCALE = "locale"
        const val EXTRA_TRIGGER_AT = "triggerAt"
        const val EXTRA_SOUND = "sound"
        const val EXTRA_RING_IN_SILENT = "ringInSilent"
        const val EXTRA_ARMED_AT = "armedAt"
        const val EXTRA_ARMED_ELAPSED = "armedElapsed"
        const val EXTRA_NEXT_AT = "nextAt"
        const val EXTRA_KEY = "key"
        const val EXTRA_TEST = "test"

        fun deliver(context: Context, prayer: String, localeCode: String, sound: String, ringInSilent: Boolean, playing: Boolean = true) {
            if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
                Log.w(TAG, "deliver: notifications disabled, skipping $prayer")
                return
            }
            val serviceIntent = Intent(context, AdhanPlaybackService::class.java).apply {
                action = AdhanPlaybackService.ACTION_PLAY
                putExtra(AdhanPlaybackService.EXTRA_PRAYER, prayer)
                putExtra(AdhanPlaybackService.EXTRA_CLIP, if (prayer == "fajr") "fajr_adhan" else "normal_adhan")
                putExtra(AdhanPlaybackService.EXTRA_LOCALE, localeCode)
            }
            context.startForegroundService(serviceIntent)
        }

        fun postLate(context: Context, prayer: String, localeCode: String, lateMinutes: Int) {
            AlertChannels.ensureAlertSilent(context)
            val ctx = localizedContext(context, localeCode)
            val nameRes = ctx.resources.getIdentifier("adhan_title_$prayer", "string", context.packageName)
                .let { if (it != 0) it else R.string.adhan_title_fajr }
            val minutesText = ctx.resources.getQuantityString(
                R.plurals.prayer_late_minutes,
                lateMinutes,
                NumberFormat.getIntegerInstance(Locale.forLanguageTag(localeCode)).format(lateMinutes),
            )
            val openPI = PendingIntent.getActivity(
                context, 0,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val notification = NotificationCompat.Builder(context, AlertChannels.ALERT_SILENT)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(ctx.getString(R.string.prayer_late_title, ctx.getString(nameRes), minutesText))
                .setContentText(ctx.getString(R.string.prayer_late_body))
                .setStyle(NotificationCompat.BigTextStyle().bigText(ctx.getString(R.string.prayer_late_body)))
                .setContentIntent(openPI)
                .addAction(0, ctx.getString(R.string.prayer_late_fix), openPI)
                .setSilent(true)
                .setAutoCancel(true)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .build()
            try {
                NotificationManagerCompat.from(context).notify(LATE_NOTIFICATION_ID, notification)
            } catch (e: SecurityException) {
                Log.w(TAG, "postLate: notification permission missing", e)
            }
        }
    }
}

package com.example.quran_app

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
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
        val localeCode = intent.getStringExtra(EXTRA_LOCALE) ?: "en"
        if (intent.getBooleanExtra(EXTRA_TEST, false)) {
            val prayer = intent.getStringExtra(EXTRA_PRAYER) ?: return
            val sound = intent.getStringExtra(EXTRA_SOUND) ?: "adhan"
            val ringInSilent = intent.getBooleanExtra(EXTRA_RING_IN_SILENT, false)
            val triggerAt = intent.getLongExtra(EXTRA_TRIGGER_AT, 0L).takeIf { it > 0L } ?: System.currentTimeMillis()
            val label = AlertPlanner.labelKey(prayer, triggerAt, TimeZone.getDefault())
            AlertChannels.ensureAll(context)
            deliver(context, prayer, label, localeCode, sound, ringInSilent, AlertPlanner.plays(sound, ringInSilent, isAudibleNow(context)))
            return
        }
        try {
            val prayer = intent.getStringExtra(EXTRA_PRAYER) ?: return
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
        val label = AlertPlanner.labelKey(prayer, triggerAt, TimeZone.getDefault())
        runCatching { AlertChannels.ensureAll(context) }
        val audible = runCatching { isAudibleNow(context) }.getOrDefault(false)
        val playing = AlertPlanner.plays(sound, ringInSilent, audible)
        val blocked = runCatching { AlertChannels.isBlocked(context, AlertPlanner.deliveryChannel(sound, playing)) }.getOrDefault(false)
        val enabled = runCatching { NotificationManagerCompat.from(context).areNotificationsEnabled() }.getOrDefault(true)
        val route = AlertPlanner.route(
            enabled,
            blocked,
            nowWall,
            nowElapsed,
            triggerAt,
            intent.longOrNull(EXTRA_NEXT_AT),
            intent.longOrNull(EXTRA_ARMED_AT),
            intent.longOrNull(EXTRA_ARMED_ELAPSED),
        )
        Log.i(TAG, "onReceive $key route=$route legacy=$legacy sound=$sound playing=$playing")
        when (route) {
            AlertPlanner.Route.SKIP -> AlertStore.writeRecord(context, key, AlertPlanner.Record(AlertPlanner.Outcome.SKIPPED, triggerAt))
            AlertPlanner.Route.MISSED -> AlertStore.writeRecord(context, key, AlertPlanner.Record(AlertPlanner.Outcome.MISSED, triggerAt))
            AlertPlanner.Route.LATE -> {
                AlertStore.writeRecord(context, key, AlertPlanner.Record(AlertPlanner.Outcome.LATE, triggerAt))
                try {
                    postLate(context, label, localeCode, ((nowWall - triggerAt) / 60_000L).toInt())
                } catch (e: Exception) {
                    Log.e(TAG, "postLate failed for $key", e)
                }
            }
            AlertPlanner.Route.DELIVER -> {
                AlertStore.writeRecord(context, key, AlertPlanner.Record(AlertPlanner.Outcome.FIRED, triggerAt))
                PrayerReminderIds.notificationIdByPrayer[prayer]?.let { NotificationManagerCompat.from(context).cancel(it) }
                deliver(context, prayer, label, localeCode, sound, ringInSilent, playing)
            }
        }
    }

    private fun Intent.longOrNull(name: String) = if (hasExtra(name)) getLongExtra(name, 0L) else null

    companion object {
        private const val TAG = "AdhanReceiver"
        const val TEXT_NOTIFICATION_ID = 201
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

        fun isAudibleNow(context: Context): Boolean {
            val audio = context.getSystemService(AudioManager::class.java) ?: return false
            val manager = context.getSystemService(NotificationManager::class.java) ?: return false
            val filter = manager.currentInterruptionFilter
            return audio.ringerMode == AudioManager.RINGER_MODE_NORMAL &&
                (filter == NotificationManager.INTERRUPTION_FILTER_ALL || filter == NotificationManager.INTERRUPTION_FILTER_UNKNOWN) &&
                audio.getStreamVolume(AudioManager.STREAM_NOTIFICATION) > 0
        }

        fun deliver(context: Context, prayer: String, label: String, localeCode: String, sound: String, ringInSilent: Boolean, playing: Boolean) {
            if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
                Log.w(TAG, "deliver: notifications disabled, skipping $prayer")
                return
            }
            if (playing) {
                val serviceIntent = Intent(context, AdhanPlaybackService::class.java).apply {
                    action = AdhanPlaybackService.ACTION_PLAY
                    putExtra(AdhanPlaybackService.EXTRA_PRAYER, prayer)
                    putExtra(AdhanPlaybackService.EXTRA_LABEL, label)
                    putExtra(AdhanPlaybackService.EXTRA_CLIP, AlertPlanner.clipFor(prayer))
                    putExtra(AdhanPlaybackService.EXTRA_LOCALE, localeCode)
                    putExtra(AdhanPlaybackService.EXTRA_RING_IN_SILENT, ringInSilent)
                }
                try {
                    ContextCompat.startForegroundService(context, serviceIntent)
                    return
                } catch (e: Exception) {
                    Log.w(TAG, "deliver: playback start failed for $prayer, posting text", e)
                }
            }
            postAdhanText(context, label, localeCode, sound)
        }

        fun postAdhanText(context: Context, label: String, localeCode: String, sound: String) {
            val channel = AlertPlanner.deliveryChannel(sound, false)
            if (AlertChannels.isBlocked(context, channel)) {
                Log.w(TAG, "postAdhanText: $channel is blocked, nothing posted for $label")
                return
            }
            val (title, body) = adhanText(localizedContext(context, localeCode), label)
            val builder = NotificationCompat.Builder(context, channel)
                .setSmallIcon(R.drawable.ic_stat_alfurqan)
                .setContentTitle(title)
                .setContentText(body)
                .setContentIntent(AdhanScheduler.openAppIntent(context))
                .setAutoCancel(true)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
            when (channel) {
                AlertChannels.ALERT_TONE -> builder.setPriority(NotificationCompat.PRIORITY_HIGH).setDefaults(NotificationCompat.DEFAULT_SOUND)
                AlertChannels.ALERT_VIBRATE -> builder.setPriority(NotificationCompat.PRIORITY_HIGH).setDefaults(NotificationCompat.DEFAULT_VIBRATE)
                else -> builder.setPriority(NotificationCompat.PRIORITY_DEFAULT)
            }
            NotificationManagerCompat.from(context).notify(TEXT_NOTIFICATION_ID, builder.build())
        }

        fun postLate(context: Context, label: String, localeCode: String, lateMinutes: Int) {
            AlertChannels.ensureAll(context)
            val ctx = localizedContext(context, localeCode)
            val prayerName = adhanText(ctx, label).first
            val minutesText = ctx.resources.getQuantityString(
                R.plurals.prayer_late_minutes,
                lateMinutes,
                NumberFormat.getIntegerInstance(Locale.forLanguageTag(localeCode)).format(lateMinutes),
            )
            val openPI = AdhanScheduler.openAppIntent(context)
            val notification = NotificationCompat.Builder(context, AlertChannels.ALERT_SILENT)
                .setSmallIcon(R.drawable.ic_stat_alfurqan)
                .setContentTitle(ctx.getString(R.string.prayer_late_title, prayerName, minutesText))
                .setContentText(ctx.getString(R.string.prayer_late_body))
                .setStyle(NotificationCompat.BigTextStyle().bigText(ctx.getString(R.string.prayer_late_body)))
                .setContentIntent(openPI)
                .addAction(0, ctx.getString(R.string.prayer_late_fix), openPI)
                .setSilent(true)
                .setAutoCancel(true)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .build()
            NotificationManagerCompat.from(context).notify(LATE_NOTIFICATION_ID, notification)
        }
    }
}

package com.example.quran_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationManagerCompat

/**
 * Fires at prayer time. Must return within 10s (Android limit on BroadcastReceiver).
 * Cancels any pending reminder notification for this prayer, then hands off
 * to AdhanPlaybackService.
 */
class AdhanAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        val prayer = intent?.getStringExtra(EXTRA_PRAYER) ?: "unknown"
        val clip = intent?.getStringExtra(EXTRA_CLIP) ?: "normal_adhan"
        val localeCode = intent?.getStringExtra(EXTRA_LOCALE) ?: "en"

        Log.i(TAG, "onReceive prayer=$prayer clip=$clip locale=$localeCode")

        // Staleness guard: AlarmManager delivers every past-due RTC alarm the
        // instant the clock jumps forward. Moving the device clock past several
        // prayers would otherwise fire a burst of adhans at once. If this alarm
        // is firing far later than its intended minute, it's a clock jump (or a
        // long Doze deferral) rather than a real prayer time — skip it.
        val triggerAt = intent?.getLongExtra(EXTRA_TRIGGER_AT, 0L) ?: 0L
        if (triggerAt > 0L) {
            val lateBy = System.currentTimeMillis() - triggerAt
            if (lateBy > STALE_THRESHOLD_MS) {
                Log.w(TAG, "onReceive: dropping stale $prayer (late by ${lateBy / 60000}m)")
                return
            }
        }

        // Dismiss the corresponding reminder notification if it's still visible —
        // otherwise the countdown sits at 00:00:00 next to the live adhan UI.
        PrayerReminderIds.notificationIdByPrayer[prayer]?.let { reminderId ->
            NotificationManagerCompat.from(context).cancel(reminderId)
            Log.i(TAG, "cancelled reminder notif id=$reminderId for $prayer")
        }

        val serviceIntent = Intent(context, AdhanPlaybackService::class.java).apply {
            action = AdhanPlaybackService.ACTION_PLAY
            putExtra(AdhanPlaybackService.EXTRA_PRAYER, prayer)
            putExtra(AdhanPlaybackService.EXTRA_CLIP, clip)
            putExtra(AdhanPlaybackService.EXTRA_LOCALE, localeCode)
        }
        context.startForegroundService(serviceIntent)
    }

    companion object {
        private const val TAG = "AdhanReceiver"
        const val EXTRA_PRAYER = "prayer"
        const val EXTRA_CLIP = "clip"
        const val EXTRA_LOCALE = "locale"
        const val EXTRA_TRIGGER_AT = "triggerAt"

        /**
         * How late an alarm may fire and still be honoured. Generous enough to
         * tolerate Doze deferral of the inexact fallback, far below the smallest
         * inter-prayer gap (~1h), so any real clock jump is caught.
         */
        private const val STALE_THRESHOLD_MS = 30L * 60L * 1000L
    }
}

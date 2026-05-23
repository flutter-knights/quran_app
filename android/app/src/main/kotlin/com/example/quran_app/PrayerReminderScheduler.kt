package com.example.quran_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import java.util.Calendar

/**
 * Schedules pre-prayer reminder alarms via [AlarmManager].
 *
 * Trigger time = prayer time minus offsetMinutes. Skips any trigger that has
 * already passed today. Cancels previously-armed reminders before re-arming.
 *
 * Logs every step under tag "PrayerReminder" so behaviour is diagnosable via
 * `adb logcat *:S PrayerReminder:V`.
 */
object PrayerReminderScheduler {

    private const val TAG = "PrayerReminder"

    /**
     * Arms today's remaining reminders.
     *
     * @param remindersByPrayer keys are lowercase prayer names, values are
     *                          positive offsets in minutes (entries with 0 or
     *                          missing prayers are ignored).
     * @param timings keys are lowercase prayer names, values are "HH:mm" 24h.
     * @param localeCode "en" or "ar" — passed through to the receiver so the
     *                   posted notification matches the app's current language.
     */
    fun armToday(
        context: Context,
        remindersByPrayer: Map<String, Int>,
        timings: Map<String, String>,
        localeCode: String,
    ) {
        Log.i(TAG, "armToday: starting (locale=$localeCode, " +
            "${remindersByPrayer.size} reminders requested)")

        cancelAll(context)

        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = Calendar.getInstance()
        var armed = 0
        var skipped = 0

        for ((prayer, offsetMinutes) in remindersByPrayer) {
            if (offsetMinutes <= 0) {
                skipped++
                continue
            }
            val rc = PrayerReminderIds.requestCodeByPrayer[prayer]
            val notifId = PrayerReminderIds.notificationIdByPrayer[prayer]
            if (rc == null || notifId == null) {
                Log.w(TAG, "armToday: unknown prayer key '$prayer'")
                skipped++
                continue
            }
            val hhmm = timings[prayer]
            if (hhmm == null) {
                Log.w(TAG, "armToday: $prayer missing timing")
                skipped++
                continue
            }
            val parts = hhmm.split(":")
            if (parts.size != 2) {
                Log.w(TAG, "armToday: $prayer bad time '$hhmm'")
                skipped++
                continue
            }
            val hour = parts[0].toIntOrNull()
            val minute = parts[1].toIntOrNull()
            if (hour == null || minute == null) {
                Log.w(TAG, "armToday: $prayer unparseable '$hhmm'")
                skipped++
                continue
            }

            val prayerCal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val triggerMs = prayerCal.timeInMillis - offsetMinutes * 60_000L
            if (triggerMs <= now.timeInMillis) {
                Log.i(TAG, "armToday: skipped $prayer (trigger in the past)")
                skipped++
                continue
            }

            val intent = Intent(context, PrayerReminderReceiver::class.java).apply {
                putExtra(PrayerReminderReceiver.EXTRA_PRAYER, prayer)
                putExtra(PrayerReminderReceiver.EXTRA_PRAYER_TIMESTAMP_MS,
                    prayerCal.timeInMillis)
                putExtra(PrayerReminderReceiver.EXTRA_NOTIFICATION_ID, notifId)
                putExtra(PrayerReminderReceiver.EXTRA_LOCALE, localeCode)
                putExtra(PrayerReminderReceiver.EXTRA_OFFSET_MINUTES,
                    offsetMinutes)
            }
            val pi = PendingIntent.getBroadcast(
                context, rc, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            try {
                am.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, triggerMs, pi,
                )
                Log.i(TAG, "armed $prayer reminder at $triggerMs " +
                    "(prayer=$hhmm, offset=${offsetMinutes}m, request=$rc)")
                armed++
            } catch (e: SecurityException) {
                Log.w(TAG, "armToday: exact denied, using inexact for $prayer")
                am.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, triggerMs, pi,
                )
                armed++
            }
        }

        Log.i(TAG, "armToday: $armed armed, $skipped skipped")
    }

    /** Cancels all armed reminder alarms AND any visible reminder notifications. */
    fun cancelAll(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for ((prayer, rc) in PrayerReminderIds.requestCodeByPrayer) {
            val intent = Intent(context, PrayerReminderReceiver::class.java)
            val pi = PendingIntent.getBroadcast(
                context, rc, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            am.cancel(pi)
        }
        // Also remove any reminder notification currently on screen.
        val nm = androidx.core.app.NotificationManagerCompat.from(context)
        for ((_, id) in PrayerReminderIds.notificationIdByPrayer) {
            nm.cancel(id)
        }
        Log.i(TAG, "cancelAll: cleared " +
            "${PrayerReminderIds.requestCodeByPrayer.size} reminders")
    }
}

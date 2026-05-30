package com.example.quran_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * Schedules pre-prayer reminder alarms via [AlarmManager].
 *
 * Trigger time = prayer time minus offsetMinutes. Skips any trigger that has
 * already passed. Cancels previously-armed reminders before re-arming.
 * Supports up to MAX_DAYS (3) days with day-indexed request codes.
 *
 * Logs every step under tag "PrayerReminder" so behaviour is diagnosable via
 * `adb logcat *:S PrayerReminder:V`.
 */
object PrayerReminderScheduler {

    private const val TAG = "PrayerReminder"
    private const val PREFS = "reminder_prefs"
    private const val KEY_SNAPSHOT = "reminder_snapshot"
    private const val MAX_DAYS = 3

    /**
     * Arms up to MAX_DAYS days of pre-prayer reminders.
     *
     * @param days             list of [AdhanScheduler.DaySchedule]; only first MAX_DAYS entries used.
     * @param remindersByPrayer keys are lowercase prayer names, values are positive
     *                          offsets in minutes (entries with 0 are ignored).
     * @param localeCode       "en" or "ar" — passed through to the receiver.
     */
    fun armDays(
        context: Context,
        days: List<AdhanScheduler.DaySchedule>,
        remindersByPrayer: Map<String, Int>,
        localeCode: String
    ) {
        Log.i(TAG, "armDays: starting (locale=$localeCode, days=${days.size}, " +
            "${remindersByPrayer.size} reminders requested)")

        cancelAll(context)

        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = System.currentTimeMillis()
        var armed = 0
        var skipped = 0

        for ((dayIndex, day) in days.take(MAX_DAYS).withIndex()) {
            // Parse "yyyy-MM-dd"
            val dateParts = day.date.split("-")
            if (dateParts.size != 3) {
                Log.w(TAG, "armDays: skipped day ${day.date} (bad date format)")
                continue
            }
            val year = dateParts[0].toIntOrNull()
            val month = dateParts[1].toIntOrNull() // 1-based in string
            val dayOfMonth = dateParts[2].toIntOrNull()
            if (year == null || month == null || dayOfMonth == null) {
                Log.w(TAG, "armDays: skipped day ${day.date} (unparseable date)")
                continue
            }

            for ((prayer, offsetMinutes) in remindersByPrayer) {
                if (offsetMinutes <= 0) {
                    skipped++
                    continue
                }
                val rc = PrayerReminderIds.requestCodeByPrayer[prayer]
                val notifId = PrayerReminderIds.notificationIdByPrayer[prayer]
                if (rc == null || notifId == null) {
                    Log.w(TAG, "armDays: unknown prayer key '$prayer'")
                    skipped++
                    continue
                }
                val hhmm = day.timings[prayer]
                if (hhmm == null) {
                    Log.w(TAG, "armDays: $prayer missing timing on ${day.date}")
                    skipped++
                    continue
                }
                val parts = hhmm.split(":")
                if (parts.size != 2) {
                    Log.w(TAG, "armDays: $prayer bad time '$hhmm' on ${day.date}")
                    skipped++
                    continue
                }
                val hour = parts[0].toIntOrNull()
                val minute = parts[1].toIntOrNull()
                if (hour == null || minute == null) {
                    Log.w(TAG, "armDays: $prayer unparseable '$hhmm' on ${day.date}")
                    skipped++
                    continue
                }

                val prayerCal = Calendar.getInstance().apply {
                    set(Calendar.YEAR, year)
                    set(Calendar.MONTH, month - 1) // Calendar.MONTH is 0-based
                    set(Calendar.DAY_OF_MONTH, dayOfMonth)
                    set(Calendar.HOUR_OF_DAY, hour)
                    set(Calendar.MINUTE, minute)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                val triggerMs = prayerCal.timeInMillis - offsetMinutes * 60_000L
                if (triggerMs <= now) {
                    Log.i(TAG, "armDays: skipped $prayer on ${day.date} (trigger in the past)")
                    skipped++
                    continue
                }

                val dayRc = rc + dayIndex * 10
                val intent = Intent(context, PrayerReminderReceiver::class.java).apply {
                    putExtra(PrayerReminderReceiver.EXTRA_PRAYER, prayer)
                    putExtra(PrayerReminderReceiver.EXTRA_PRAYER_TIMESTAMP_MS,
                        prayerCal.timeInMillis)
                    putExtra(PrayerReminderReceiver.EXTRA_NOTIFICATION_ID, notifId)
                    putExtra(PrayerReminderReceiver.EXTRA_LOCALE, localeCode)
                    putExtra(PrayerReminderReceiver.EXTRA_OFFSET_MINUTES, offsetMinutes)
                }
                val pi = PendingIntent.getBroadcast(
                    context, dayRc, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )

                try {
                    am.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, triggerMs, pi,
                    )
                    Log.i(TAG, "armed $prayer reminder on ${day.date} at $hhmm " +
                        "(offset=${offsetMinutes}m, request=$dayRc, day=$dayIndex)")
                    armed++
                } catch (e: SecurityException) {
                    Log.w(TAG, "armDays: exact denied, using inexact for $prayer on ${day.date}")
                    am.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, triggerMs, pi,
                    )
                    armed++
                }
            }
        }

        // Persist full requested snapshot for boot re-arm.
        saveSnapshot(context, days, remindersByPrayer, localeCode)

        Log.i(TAG, "armDays: $armed armed, $skipped skipped")
    }

    /**
     * Arms today's remaining reminders. Kept for backward-compat.
     *
     * @param remindersByPrayer keys are lowercase prayer names, values are
     *                          positive offsets in minutes.
     * @param timings keys are lowercase prayer names, values are "HH:mm" 24h.
     * @param localeCode "en" or "ar".
     */
    fun armToday(
        context: Context,
        remindersByPrayer: Map<String, Int>,
        timings: Map<String, String>,
        localeCode: String,
    ) {
        val now = Calendar.getInstance()
        val today = "%04d-%02d-%02d".format(
            now.get(Calendar.YEAR),
            now.get(Calendar.MONTH) + 1,
            now.get(Calendar.DAY_OF_MONTH)
        )
        armDays(context, listOf(AdhanScheduler.DaySchedule(today, timings)), remindersByPrayer, localeCode)
    }

    /** Cancels ALL day-indexed reminder alarms AND any visible reminder notifications. */
    fun cancelAll(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        var count = 0
        for ((_, rc) in PrayerReminderIds.requestCodeByPrayer) {
            for (d in 0 until MAX_DAYS) {
                val intent = Intent(context, PrayerReminderReceiver::class.java)
                val pi = PendingIntent.getBroadcast(
                    context, rc + d * 10, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                am.cancel(pi)
                count++
            }
        }
        // Also remove any reminder notification currently on screen.
        val nm = androidx.core.app.NotificationManagerCompat.from(context)
        for ((_, id) in PrayerReminderIds.notificationIdByPrayer) {
            nm.cancel(id)
        }
        Log.i(TAG, "cancelAll: cleared $count reminder alarm slots")
    }

    /**
     * Persists a snapshot of the requested schedule to SharedPrefs so it can be
     * re-armed after device boot.
     */
    private fun saveSnapshot(
        context: Context,
        days: List<AdhanScheduler.DaySchedule>,
        remindersByPrayer: Map<String, Int>,
        localeCode: String
    ) {
        try {
            val daysArray = JSONArray()
            for (day in days) {
                val timingsObj = JSONObject()
                for ((k, v) in day.timings) timingsObj.put(k, v)
                daysArray.put(JSONObject().put("date", day.date).put("timings", timingsObj))
            }
            val remindersObj = JSONObject()
            for ((k, v) in remindersByPrayer) remindersObj.put(k, v)
            val snapshot = JSONObject()
                .put("days", daysArray)
                .put("reminders", remindersObj)
                .put("locale", localeCode)
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putString(KEY_SNAPSHOT, snapshot.toString()).apply()
            Log.i(TAG, "saveSnapshot: saved ${days.size} days")
        } catch (e: Exception) {
            Log.e(TAG, "saveSnapshot: failed", e)
        }
    }

    /**
     * Reads the persisted snapshot and re-arms. Called on boot/package-replace.
     * Past triggers are skipped automatically by [armDays].
     */
    fun rearmFromSnapshot(context: Context) {
        try {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val json = prefs.getString(KEY_SNAPSHOT, null)
            if (json == null) {
                Log.i(TAG, "rearmFromSnapshot: no snapshot found, nothing to re-arm")
                return
            }
            val obj = JSONObject(json)
            val daysArray = obj.getJSONArray("days")
            val days = mutableListOf<AdhanScheduler.DaySchedule>()
            for (i in 0 until daysArray.length()) {
                val d = daysArray.getJSONObject(i)
                val date = d.getString("date")
                val timingsObj = d.getJSONObject("timings")
                val timings = mutableMapOf<String, String>()
                for (key in timingsObj.keys()) {
                    timings[key] = timingsObj.getString(key)
                }
                days.add(AdhanScheduler.DaySchedule(date, timings))
            }
            val remindersObj = obj.getJSONObject("reminders")
            val remindersByPrayer = mutableMapOf<String, Int>()
            for (key in remindersObj.keys()) {
                remindersByPrayer[key] = remindersObj.getInt(key)
            }
            val localeCode = obj.optString("locale", "en")
            Log.i(TAG, "rearmFromSnapshot: re-arming ${days.size} days (locale=$localeCode)")
            armDays(context, days, remindersByPrayer, localeCode)
        } catch (e: Exception) {
            Log.e(TAG, "rearmFromSnapshot: failed to parse/re-arm snapshot", e)
        }
    }
}

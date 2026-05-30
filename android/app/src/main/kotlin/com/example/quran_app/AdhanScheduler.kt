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
 * Schedules per-prayer adhan alarms via [AlarmManager].
 * - Cancels any previously-armed alarms first (request codes 200..224).
 * - Supports up to MAX_DAYS (3) days of scheduling, with day-indexed request codes.
 * - Skips any prayers whose time has already passed.
 * - Each alarm fires AdhanAlarmReceiver with extras (prayer, clipResName).
 *
 * Logs every step under tag "Adhan" so issue #1 (silent failure) is diagnosable
 * via `adb logcat *:S Adhan:V`.
 */
object AdhanScheduler {

    private const val TAG = "Adhan"
    private const val PREFS = "adhan_prefs"
    private const val KEY_DATE = "armed_for_date"
    private const val KEY_SNAPSHOT = "adhan_snapshot"
    private const val MAX_DAYS = 3

    // Stable request code per prayer (must NOT collide with PrayerAlarmReceiver 0..5).
    // Day d uses: REQUEST_CODES[prayer]!! + d*10
    // day0=200..204, day1=210..214, day2=220..224
    private val REQUEST_CODES = mapOf(
        "fajr" to 200,
        "dhuhr" to 201,
        "asr" to 202,
        "maghrib" to 203,
        "isha" to 204
    )

    private val PRAYERS_WITH_ADHAN = listOf("fajr", "dhuhr", "asr", "maghrib", "isha")

    /**
     * Represents one day's schedule (date string + prayer timings).
     */
    data class DaySchedule(val date: String, val timings: Map<String, String>)

    /**
     * Arms up to MAX_DAYS days of prayer adhans.
     *
     * @param days         list of [DaySchedule]; only first MAX_DAYS entries are used.
     * @param clipResNames keys are lowercase prayer names, values are the basename
     *                     of a raw resource (e.g. "fajr_adhan" matches R.raw.fajr_adhan).
     * @param localeCode   "en" or "ar" — passed to the receiver so the notification
     *                     body uses the right language at fire time.
     */
    fun armDays(
        context: Context,
        days: List<DaySchedule>,
        clipResNames: Map<String, String>,
        localeCode: String
    ) {
        Log.i(TAG, "armDays: starting (locale=$localeCode, days=${days.size})")

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

            for (prayer in PRAYERS_WITH_ADHAN) {
                val hhmm = day.timings[prayer]
                val clip = clipResNames[prayer]
                if (hhmm == null || clip == null) {
                    Log.w(TAG, "armDays: skipped $prayer on ${day.date} (missing timing or clip)")
                    skipped++
                    continue
                }

                val parts = hhmm.split(":")
                if (parts.size != 2) {
                    Log.w(TAG, "armDays: skipped $prayer on ${day.date} (bad time format: $hhmm)")
                    skipped++
                    continue
                }
                val hour = parts[0].toIntOrNull()
                val minute = parts[1].toIntOrNull()
                if (hour == null || minute == null) {
                    Log.w(TAG, "armDays: skipped $prayer on ${day.date} (unparseable: $hhmm)")
                    skipped++
                    continue
                }

                val trigger = Calendar.getInstance().apply {
                    set(Calendar.YEAR, year)
                    set(Calendar.MONTH, month - 1) // Calendar.MONTH is 0-based
                    set(Calendar.DAY_OF_MONTH, dayOfMonth)
                    set(Calendar.HOUR_OF_DAY, hour)
                    set(Calendar.MINUTE, minute)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }

                if (trigger.timeInMillis <= now) {
                    Log.i(TAG, "armDays: skipped $prayer on ${day.date} (past: $hhmm)")
                    skipped++
                    continue
                }

                val rc = REQUEST_CODES[prayer]!! + dayIndex * 10
                val intent = Intent(context, AdhanAlarmReceiver::class.java).apply {
                    putExtra(AdhanAlarmReceiver.EXTRA_PRAYER, prayer)
                    putExtra(AdhanAlarmReceiver.EXTRA_CLIP, clip)
                    putExtra(AdhanAlarmReceiver.EXTRA_LOCALE, localeCode)
                    putExtra(AdhanAlarmReceiver.EXTRA_TRIGGER_AT, trigger.timeInMillis)
                }
                val pi = PendingIntent.getBroadcast(
                    context, rc, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                try {
                    am.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, trigger.timeInMillis, pi
                    )
                    Log.i(TAG, "armed $prayer on ${day.date} at $hhmm (request=$rc, day=$dayIndex)")
                    armed++
                } catch (e: SecurityException) {
                    // SCHEDULE_EXACT_ALARM denied — fall back to inexact.
                    Log.w(TAG, "armDays: SCHEDULE_EXACT_ALARM denied, using inexact for $prayer on ${day.date}")
                    am.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, trigger.timeInMillis, pi
                    )
                    armed++
                }
            }
        }

        // Persist full requested snapshot for boot re-arm.
        saveSnapshot(context, days, clipResNames, localeCode)

        Log.i(TAG, "armDays: $armed armed, $skipped skipped")
    }

    /**
     * Arms today's remaining prayers. Delegates to [armDays] for backward-compat.
     *
     * @param timings keys are lowercase prayer names ("fajr", "sunrise", "dhuhr"…),
     *                values are "HH:mm" 24-hour strings.
     * @param clipResNames keys are lowercase prayer names, values are the basename
     *                     of a raw resource (e.g. "fajr_adhan" matches R.raw.fajr_adhan).
     * @param localeCode "en" or "ar" — passed to the receiver so the notification
     *                   body uses the right language at fire time.
     */
    fun armToday(
        context: Context,
        timings: Map<String, String>,
        clipResNames: Map<String, String>,
        localeCode: String
    ) {
        val now = Calendar.getInstance()
        val today = "%04d-%02d-%02d".format(
            now.get(Calendar.YEAR),
            now.get(Calendar.MONTH) + 1,
            now.get(Calendar.DAY_OF_MONTH)
        )
        armDays(context, listOf(DaySchedule(today, timings)), clipResNames, localeCode)
        // Also persist the armed_for_date key for backward-compat diagnostics.
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_DATE, today).apply()
    }

    /** Cancels ALL day-indexed adhan alarms (day 0..MAX_DAYS-1). Idempotent. */
    fun cancelAll(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        var count = 0
        for ((_, rc) in REQUEST_CODES) {
            for (d in 0 until MAX_DAYS) {
                val intent = Intent(context, AdhanAlarmReceiver::class.java)
                val pi = PendingIntent.getBroadcast(
                    context, rc + d * 10, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                am.cancel(pi)
                count++
            }
        }
        Log.i(TAG, "cancelAll: cleared $count alarm slots")
    }

    /**
     * Persists a snapshot of the requested schedule to SharedPrefs so it can be
     * re-armed after device boot.
     */
    private fun saveSnapshot(
        context: Context,
        days: List<DaySchedule>,
        clips: Map<String, String>,
        localeCode: String
    ) {
        try {
            val daysArray = JSONArray()
            for (day in days) {
                val timingsObj = JSONObject()
                for ((k, v) in day.timings) timingsObj.put(k, v)
                daysArray.put(JSONObject().put("date", day.date).put("timings", timingsObj))
            }
            val clipsObj = JSONObject()
            for ((k, v) in clips) clipsObj.put(k, v)
            val snapshot = JSONObject()
                .put("days", daysArray)
                .put("clips", clipsObj)
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
            val days = mutableListOf<DaySchedule>()
            for (i in 0 until daysArray.length()) {
                val d = daysArray.getJSONObject(i)
                val date = d.getString("date")
                val timingsObj = d.getJSONObject("timings")
                val timings = mutableMapOf<String, String>()
                for (key in timingsObj.keys()) {
                    timings[key] = timingsObj.getString(key)
                }
                days.add(DaySchedule(date, timings))
            }
            val clipsObj = obj.getJSONObject("clips")
            val clips = mutableMapOf<String, String>()
            for (key in clipsObj.keys()) {
                clips[key] = clipsObj.getString(key)
            }
            val localeCode = obj.optString("locale", "en")
            Log.i(TAG, "rearmFromSnapshot: re-arming ${days.size} days (locale=$localeCode)")
            armDays(context, days, clips, localeCode)
        } catch (e: Exception) {
            Log.e(TAG, "rearmFromSnapshot: failed to parse/re-arm snapshot", e)
        }
    }

    /** One-shot test alarm: fires `delaySeconds` from now with normal_adhan. */
    fun armTest(context: Context, delaySeconds: Int, localeCode: String) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val trigger = System.currentTimeMillis() + delaySeconds * 1000L
        val intent = Intent(context, AdhanAlarmReceiver::class.java).apply {
            putExtra(AdhanAlarmReceiver.EXTRA_PRAYER, "dhuhr")
            putExtra(AdhanAlarmReceiver.EXTRA_CLIP, "normal_adhan")
            putExtra(AdhanAlarmReceiver.EXTRA_LOCALE, localeCode)
            putExtra(AdhanAlarmReceiver.EXTRA_TRIGGER_AT, trigger)
        }
        val pi = PendingIntent.getBroadcast(
            context, 299, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        try {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pi)
        } catch (e: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pi)
        }
        Log.i(TAG, "armTest: in ${delaySeconds}s (request=299)")
    }
}

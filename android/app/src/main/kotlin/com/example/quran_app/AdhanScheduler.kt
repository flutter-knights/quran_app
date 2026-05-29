package com.example.quran_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import java.util.Calendar

/**
 * Schedules per-prayer adhan alarms via [AlarmManager].
 * - Cancels any previously-armed alarms first (request codes 200..205).
 * - Skips sunrise (no adhan) and any prayers whose time has already passed today.
 * - Each alarm fires AdhanAlarmReceiver with extras (prayer, clipResName).
 *
 * Logs every step under tag "Adhan" so issue #1 (silent failure) is diagnosable
 * via `adb logcat *:S Adhan:V`.
 */
object AdhanScheduler {

    private const val TAG = "Adhan"
    private const val PREFS = "adhan_prefs"
    private const val KEY_DATE = "armed_for_date"

    // Stable request code per prayer (must NOT collide with PrayerAlarmReceiver 0..5).
    private val REQUEST_CODES = mapOf(
        "fajr" to 200,
        "dhuhr" to 201,
        "asr" to 202,
        "maghrib" to 203,
        "isha" to 204
    )

    private val PRAYERS_WITH_ADHAN = listOf("fajr", "dhuhr", "asr", "maghrib", "isha")

    /**
     * Arms today's remaining prayers.
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
        Log.i(TAG, "armToday: starting (locale=$localeCode, " +
            "timings=${timings.keys.size} prayers)")

        cancelAll(context)

        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = Calendar.getInstance()
        val today = "%04d-%02d-%02d".format(
            now.get(Calendar.YEAR),
            now.get(Calendar.MONTH) + 1,
            now.get(Calendar.DAY_OF_MONTH)
        )

        var armed = 0
        var skipped = 0
        for (prayer in PRAYERS_WITH_ADHAN) {
            val hhmm = timings[prayer]
            val clip = clipResNames[prayer]
            if (hhmm == null || clip == null) {
                Log.w(TAG, "armToday: skipped $prayer (missing timing or clip)")
                skipped++
                continue
            }

            val parts = hhmm.split(":")
            if (parts.size != 2) {
                Log.w(TAG, "armToday: skipped $prayer (bad time format: $hhmm)")
                skipped++
                continue
            }
            val hour = parts[0].toIntOrNull()
            val minute = parts[1].toIntOrNull()
            if (hour == null || minute == null) {
                Log.w(TAG, "armToday: skipped $prayer (unparseable: $hhmm)")
                skipped++
                continue
            }

            val trigger = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            if (trigger.timeInMillis <= now.timeInMillis) {
                Log.i(TAG, "armToday: skipped $prayer (past: $hhmm)")
                skipped++
                continue
            }

            val rc = REQUEST_CODES[prayer]!!
            val intent = Intent(context, AdhanAlarmReceiver::class.java).apply {
                putExtra(AdhanAlarmReceiver.EXTRA_PRAYER, prayer)
                putExtra(AdhanAlarmReceiver.EXTRA_CLIP, clip)
                putExtra(AdhanAlarmReceiver.EXTRA_LOCALE, localeCode)
                // Lets the receiver drop this alarm if a clock jump fires it
                // long after its intended minute (see AdhanAlarmReceiver).
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
                Log.i(TAG, "armed $prayer at $today $hhmm (request=$rc)")
                armed++
            } catch (e: SecurityException) {
                // SCHEDULE_EXACT_ALARM denied — fall back to inexact.
                Log.w(TAG, "armToday: SCHEDULE_EXACT_ALARM denied, using inexact for $prayer")
                am.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, trigger.timeInMillis, pi
                )
                armed++
            }
        }

        // Persist for diagnostic visibility.
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_DATE, today).apply()

        Log.i(TAG, "armToday: $armed armed, $skipped skipped")
    }

    /** Cancels all armed adhan alarms. Idempotent. */
    fun cancelAll(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for ((prayer, rc) in REQUEST_CODES) {
            val intent = Intent(context, AdhanAlarmReceiver::class.java)
            val pi = PendingIntent.getBroadcast(
                context, rc, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            am.cancel(pi)
        }
        Log.i(TAG, "cancelAll: cleared ${REQUEST_CODES.size} alarms")
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

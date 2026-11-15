package com.example.quran_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.util.Log
import java.util.Calendar
import java.util.TimeZone

object AdhanScheduler {

    private const val TAG = "Adhan"
    const val USE_ALARM_CLOCK = true

    fun sync(context: Context, snapshot: AlertPlanner.AdhanSnapshot) {
        AlertChannels.ensureAll(context)
        AlertStore.writeSnapshot(context, AlertStore.ADHAN_PREFS, AlertStore.ADHAN_SNAPSHOT, AlertPlanner.encodeAdhanSnapshot(snapshot))
        AlertStore.setIfUnset(context, AlertStore.LAST_CHECKED_AT, System.currentTimeMillis())
        armDays(context, snapshot)
    }

    fun armDays(context: Context, snapshot: AlertPlanner.AdhanSnapshot) {
        val now = System.currentTimeMillis()
        val elapsed = SystemClock.elapsedRealtime()
        val plan = AlertPlanner.planAdhans(snapshot.days, snapshot.alerts, now, TimeZone.getDefault())
        val recorded = AlertStore.readRecords(context).keys
        AlarmSlots.arm(context, AdhanAlarmReceiver::class.java, AlertPlanner.ADHAN_BASE, plan, recorded, now, USE_ALARM_CLOCK) { alarm ->
            val spec = snapshot.alerts.getValue(alarm.prayer)
            putExtra(AdhanAlarmReceiver.EXTRA_KEY, alarm.key)
            putExtra(AdhanAlarmReceiver.EXTRA_PRAYER, alarm.prayer)
            putExtra(AdhanAlarmReceiver.EXTRA_LOCALE, snapshot.localeCode)
            putExtra(AdhanAlarmReceiver.EXTRA_TRIGGER_AT, alarm.triggerAt)
            putExtra(AdhanAlarmReceiver.EXTRA_SOUND, spec.sound)
            putExtra(AdhanAlarmReceiver.EXTRA_RING_IN_SILENT, spec.ringInSilent)
            putExtra(AdhanAlarmReceiver.EXTRA_NEXT_AT, alarm.nextAt)
            putExtra(AdhanAlarmReceiver.EXTRA_ARMED_AT, now)
            putExtra(AdhanAlarmReceiver.EXTRA_ARMED_ELAPSED, elapsed)
        }

        val kept = AlertStore.readArmed(context).filterValues { it.triggerAt <= now }
        val armed = kept + plan.associate { it.key to AlertPlanner.ArmedEntry(it.triggerAt, now) }
        AlertStore.writeArmed(context, AlertPlanner.pruneArmed(armed, now))
        if (plan.isEmpty()) {
            AlertStore.remove(context, AlertStore.SCHEDULED_UNTIL)
        } else {
            AlertStore.setLong(context, AlertStore.SCHEDULED_UNTIL, plan.maxOf { it.triggerAt })
        }
        armHeal(context)
        Log.i(TAG, "armDays: ${plan.size} armed (legacy=${snapshot.legacy})")
    }

    fun rearmFromSnapshot(context: Context) {
        AlertStore.readSnapshot(context, AlertStore.ADHAN_PREFS, AlertStore.ADHAN_SNAPSHOT)?.let { json ->
            val snapshot = try {
                AlertPlanner.parseAdhanSnapshot(json)
            } catch (e: Exception) {
                Log.e(TAG, "rearmFromSnapshot: adhan snapshot unreadable, keeping armed alarms", e)
                null
            }
            snapshot?.let { armDays(context, it) }
        }
        AlertStore.readSnapshot(context, AlertStore.REMINDER_PREFS, AlertStore.REMINDER_SNAPSHOT)?.let { json ->
            val snapshot = try {
                AlertPlanner.parseReminderSnapshot(json)
            } catch (e: Exception) {
                Log.e(TAG, "rearmFromSnapshot: reminder snapshot unreadable, keeping armed alarms", e)
                null
            }
            snapshot?.let { PrayerReminderScheduler.armDays(context, it) }
        }
    }

    fun armHeal(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val trigger = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 5)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_MONTH, 1)
        }.timeInMillis
        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, healIntent(context))
    }

    fun cancelAll(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        AlarmSlots.cancelAll(context, AdhanAlarmReceiver::class.java, AlertPlanner.ADHAN_BASE)
        am.cancel(healIntent(context))
        AlertStore.writeSnapshot(context, AlertStore.ADHAN_PREFS, AlertStore.ADHAN_SNAPSHOT, null)
        val now = System.currentTimeMillis()
        AlertStore.writeArmed(context, AlertPlanner.pruneArmed(AlertStore.readArmed(context).filterValues { it.triggerAt <= now }, now))
        AlertStore.remove(context, AlertStore.SCHEDULED_UNTIL)
        Log.i(TAG, "cancelAll: cleared adhan slots, heal alarm and snapshot")
    }

    fun testExtras(localeCode: String, sound: String, ringInSilent: Boolean, triggerAt: Long): Map<String, Any> = mapOf(
        AdhanAlarmReceiver.EXTRA_PRAYER to "dhuhr",
        AdhanAlarmReceiver.EXTRA_LOCALE to localeCode,
        AdhanAlarmReceiver.EXTRA_TRIGGER_AT to triggerAt,
        AdhanAlarmReceiver.EXTRA_SOUND to sound,
        AdhanAlarmReceiver.EXTRA_RING_IN_SILENT to ringInSilent,
        AdhanAlarmReceiver.EXTRA_TEST to true,
    )

    fun armTest(context: Context, delaySeconds: Int, localeCode: String, sound: String, ringInSilent: Boolean) {
        val trigger = System.currentTimeMillis() + delaySeconds * 1000L
        val intent = Intent(context, AdhanAlarmReceiver::class.java)
        for ((k, v) in testExtras(localeCode, sound, ringInSilent, trigger)) {
            when (v) {
                is String -> intent.putExtra(k, v)
                is Boolean -> intent.putExtra(k, v)
                is Long -> intent.putExtra(k, v)
            }
        }
        val pi = PendingIntent.getBroadcast(context, AlertPlanner.TEST_REQUEST_CODE, intent, AlarmSlots.FLAGS)
        AlarmSlots.schedule(context, trigger, pi, alarmClock = false)
        Log.i(TAG, "armTest: in ${delaySeconds}s")
    }

    private fun healIntent(context: Context) = PendingIntent.getBroadcast(
        context, AlertPlanner.HEAL_REQUEST_CODE, Intent(context, AdhanHealReceiver::class.java), AlarmSlots.FLAGS,
    )

    fun openAppIntent(context: Context): PendingIntent = PendingIntent.getActivity(
        context, 0,
        Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        },
        AlarmSlots.FLAGS,
    )
}

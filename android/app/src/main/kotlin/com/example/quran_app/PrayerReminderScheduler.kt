package com.example.quran_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import java.util.TimeZone

object PrayerReminderScheduler {

    private const val TAG = "PrayerReminder"
    private const val FLAGS = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

    fun sync(context: Context, snapshot: AlertPlanner.ReminderSnapshot) {
        AlertStore.writeSnapshot(context, AlertStore.REMINDER_PREFS, AlertStore.REMINDER_SNAPSHOT, AlertPlanner.encodeReminderSnapshot(snapshot))
        armDays(context, snapshot)
    }

    fun armDays(context: Context, snapshot: AlertPlanner.ReminderSnapshot) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val plan = AlertPlanner.planReminders(snapshot.days, snapshot.reminders, System.currentTimeMillis(), TimeZone.getDefault())
        for (alarm in plan) {
            val spec = snapshot.reminders.getValue(alarm.prayer)
            val notifId = PrayerReminderIds.notificationIdByPrayer[alarm.prayer] ?: continue
            val intent = Intent(context, PrayerReminderReceiver::class.java).apply {
                putExtra(PrayerReminderReceiver.EXTRA_PRAYER, alarm.prayer)
                putExtra(PrayerReminderReceiver.EXTRA_PRAYER_TIMESTAMP_MS, alarm.prayerAt)
                putExtra(PrayerReminderReceiver.EXTRA_NOTIFICATION_ID, notifId)
                putExtra(PrayerReminderReceiver.EXTRA_LOCALE, snapshot.localeCode)
                putExtra(PrayerReminderReceiver.EXTRA_OFFSET_MINUTES, spec.minutes)
                putExtra(PrayerReminderReceiver.EXTRA_REMINDER_SOUND, spec.reminderSound)
            }
            val pi = PendingIntent.getBroadcast(context, alarm.requestCode, intent, FLAGS)
            try {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, alarm.triggerAt, pi)
            } catch (e: SecurityException) {
                Log.w(TAG, "armDays: exact denied, inexact for ${alarm.key}")
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, alarm.triggerAt, pi)
            }
        }
        cancelSlots(context, AlertPlanner.staleRequestCodes(AlertPlanner.REMINDER_BASE, plan.map { it.requestCode }.toSet()))
        Log.i(TAG, "armDays: ${plan.size} armed (legacy=${snapshot.legacy})")
    }

    fun cancelAll(context: Context) {
        cancelSlots(context, AlertPlanner.staleRequestCodes(AlertPlanner.REMINDER_BASE, emptySet()))
        AlertStore.writeSnapshot(context, AlertStore.REMINDER_PREFS, AlertStore.REMINDER_SNAPSHOT, null)
        val nm = NotificationManagerCompat.from(context)
        for (id in PrayerReminderIds.notificationIdByPrayer.values) nm.cancel(id)
        Log.i(TAG, "cancelAll: cleared reminder slots and snapshot")
    }

    private fun cancelSlots(context: Context, codes: List<Int>) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (rc in codes) {
            am.cancel(PendingIntent.getBroadcast(context, rc, Intent(context, PrayerReminderReceiver::class.java), FLAGS))
        }
    }
}

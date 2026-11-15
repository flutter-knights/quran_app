package com.example.quran_app

import android.content.Context
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import java.util.TimeZone

object PrayerReminderScheduler {

    private const val TAG = "PrayerReminder"

    fun sync(context: Context, snapshot: AlertPlanner.ReminderSnapshot) {
        AlertStore.writeSnapshot(context, AlertStore.REMINDER_PREFS, AlertStore.REMINDER_SNAPSHOT, AlertPlanner.encodeReminderSnapshot(snapshot))
        armDays(context, snapshot)
    }

    fun armDays(context: Context, snapshot: AlertPlanner.ReminderSnapshot) {
        val now = System.currentTimeMillis()
        val plan = AlertPlanner.planReminders(snapshot.days, snapshot.reminders, now, TimeZone.getDefault())
        AlarmSlots.arm(context, PrayerReminderReceiver::class.java, AlertPlanner.REMINDER_BASE, plan, emptySet(), now, alarmClock = false) { alarm ->
            val spec = snapshot.reminders.getValue(alarm.prayer)
            putExtra(PrayerReminderReceiver.EXTRA_PRAYER, alarm.prayer)
            putExtra(PrayerReminderReceiver.EXTRA_PRAYER_TIMESTAMP_MS, alarm.prayerAt)
            putExtra(PrayerReminderReceiver.EXTRA_NOTIFICATION_ID, PrayerReminderIds.notificationIdByPrayer.getValue(alarm.prayer))
            putExtra(PrayerReminderReceiver.EXTRA_LOCALE, snapshot.localeCode)
            putExtra(PrayerReminderReceiver.EXTRA_OFFSET_MINUTES, spec.minutes)
            putExtra(PrayerReminderReceiver.EXTRA_REMINDER_SOUND, spec.reminderSound)
        }
        Log.i(TAG, "armDays: ${plan.size} armed (legacy=${snapshot.legacy})")
    }

    fun cancelAll(context: Context) {
        AlarmSlots.cancelAll(context, PrayerReminderReceiver::class.java, AlertPlanner.REMINDER_BASE)
        AlertStore.writeSnapshot(context, AlertStore.REMINDER_PREFS, AlertStore.REMINDER_SNAPSHOT, null)
        val nm = NotificationManagerCompat.from(context)
        for (id in PrayerReminderIds.notificationIdByPrayer.values) nm.cancel(id)
        Log.i(TAG, "cancelAll: cleared reminder slots and snapshot")
    }
}

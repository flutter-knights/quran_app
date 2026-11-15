package com.example.quran_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

object AlarmSlots {

    private const val TAG = "AlarmSlots"
    const val FLAGS = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

    fun arm(
        context: Context,
        receiver: Class<out BroadcastReceiver>,
        base: Int,
        plan: List<AlertPlanner.PlannedAlarm>,
        recorded: Set<String>,
        now: Long,
        alarmClock: Boolean,
        fill: Intent.(AlertPlanner.PlannedAlarm) -> Unit,
    ) {
        for (alarm in plan) {
            val intent = Intent(context, receiver).apply { fill(alarm) }
            schedule(context, alarm.triggerAt, PendingIntent.getBroadcast(context, alarm.requestCode, intent, FLAGS), alarmClock)
        }
        val slots = AlertPlanner.planSlots(base, plan, AlertStore.readSlots(context, base), recorded, now)
        cancel(context, receiver, slots.cancel)
        AlertStore.writeSlots(context, base, slots.slots)
    }

    fun cancelAll(context: Context, receiver: Class<out BroadcastReceiver>, base: Int) {
        cancel(context, receiver, AlertPlanner.staleRequestCodes(base, emptySet()))
        AlertStore.writeSlots(context, base, emptyList())
    }

    fun schedule(context: Context, triggerAt: Long, pi: PendingIntent, alarmClock: Boolean) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try {
            if (alarmClock) {
                am.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAt, AdhanScheduler.openAppIntent(context)), pi)
            } else {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "schedule: exact denied, using inexact")
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
        }
    }

    private fun cancel(context: Context, receiver: Class<out BroadcastReceiver>, codes: List<Int>) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (rc in codes) am.cancel(PendingIntent.getBroadcast(context, rc, Intent(context, receiver), FLAGS))
    }
}

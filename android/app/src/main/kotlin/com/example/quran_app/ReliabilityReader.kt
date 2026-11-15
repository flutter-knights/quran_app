package com.example.quran_app

import android.app.AlarmManager
import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.app.NotificationManagerCompat

object ReliabilityReader {

    private const val TAG = "ReliabilityReader"

    fun read(context: Context): Map<String, Any?> {
        val now = System.currentTimeMillis()
        val snapshot = AlertStore.readSnapshot(context, AlertStore.ADHAN_PREFS, AlertStore.ADHAN_SNAPSHOT)?.let {
            try {
                AlertPlanner.parseAdhanSnapshot(it)
            } catch (e: Exception) {
                Log.w(TAG, "read: adhan snapshot unreadable", e)
                null
            }
        }
        val channelBlocked = AlertPlanner.statusChannels(snapshot?.alerts.orEmpty()).any {
            runCatching { AlertChannels.isBlocked(context, it) }.getOrDefault(false)
        }
        val os = AlertPlanner.OsState(
            notificationsEnabled = runCatching { NotificationManagerCompat.from(context).areNotificationsEnabled() }.getOrDefault(true),
            channelBlocked = channelBlocked,
            exactAlarmsAllowed = AlertPlanner.exactAlarmsAllowed(Build.VERSION.SDK_INT) { canScheduleExact(context) },
            batteryUnrestricted = runCatching {
                (context.getSystemService(Context.POWER_SERVICE) as PowerManager).isIgnoringBatteryOptimizations(context.packageName)
            }.getOrDefault(true),
            isXiaomi = AlertPlanner.isXiaomi(Build.MANUFACTURER, Build.BRAND),
        )
        val records = AlertStore.readRecords(context)
        val lastCheckedAt = AlertStore.getLong(context, AlertStore.LAST_CHECKED_AT) ?: 0L
        val missed = AlertPlanner.detectMisses(
            AlertStore.readArmed(context), records, lastCheckedAt,
            AlertStore.getLong(context, AlertStore.LAST_BOOT_HANDLED_AT) ?: 0L,
            AlertStore.getLong(context, AlertStore.LAST_CLOCK_CHANGE_AT) ?: 0L,
            now,
        )
        return AlertPlanner.statusMap(
            os,
            usesAlarmClock = AdhanScheduler.USE_ALARM_CLOCK,
            scheduledUntil = AlertStore.getLong(context, AlertStore.SCHEDULED_UNTIL),
            snapshotUntil = snapshot?.let { AlertPlanner.snapshotUntil(it.days) },
            missed = missed,
            late = AlertPlanner.lateSince(records, lastCheckedAt),
        )
    }

    fun ack(context: Context, upTo: Long) {
        val current = AlertStore.getLong(context, AlertStore.LAST_CHECKED_AT)
        AlertStore.setLong(context, AlertStore.LAST_CHECKED_AT, AlertPlanner.ackCheckpoint(current, upTo))
    }

    @RequiresApi(Build.VERSION_CODES.S)
    fun canScheduleExact(context: Context) =
        runCatching { (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).canScheduleExactAlarms() }.getOrDefault(true)
}

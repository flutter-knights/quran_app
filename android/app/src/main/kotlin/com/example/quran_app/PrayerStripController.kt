package com.example.quran_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationManagerCompat
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Drives the pinned prayer strip as an ordinary ongoing notification — NO
 * foreground service. show/refresh/hide are invoked in-process by the plugin,
 * the alarm receiver, and the boot receiver. Exact alarms (each prayer + one
 * minute past midnight) re-post the notification, so it survives Doze and day
 * rollover without a long-lived service (avoids the Android-15 dataSync FGS
 * 6h/day timeout and the boot/alarm FGS-start restrictions).
 */
object PrayerStripController {

    private const val MIDNIGHT_REQUEST_CODE = 99

    fun show(context: Context, windowJson: String) {
        val ctx = context.applicationContext
        PrayerStripStateStore(ctx).save(windowJson)
        renderCurrentDay(ctx)
    }

    fun refresh(context: Context) = renderCurrentDay(context.applicationContext)

    fun hide(context: Context) {
        val ctx = context.applicationContext
        PrayerStripStateStore(ctx).clear()
        cancelAlarms(ctx)
        NotificationManagerCompat.from(ctx).cancel(PrayerStripRenderer.NOTIFICATION_ID)
    }

    private fun renderCurrentDay(ctx: Context) {
        val window = PrayerStripStateStore(ctx).load() ?: return
        val today = todayKey()
        val day = window.days.firstOrNull { it.dateKey == today }
        if (day == null) {
            // Cached window exhausted — clear the (now stale) strip until the
            // app reopens and re-arms a fresh window.
            cancelAlarms(ctx)
            NotificationManagerCompat.from(ctx).cancel(PrayerStripRenderer.NOTIFICATION_ID)
            return
        }
        val renderer = PrayerStripRenderer(ctx)
        renderer.ensureChannel()
        val nextIndex = computeNextIndex(day)
        NotificationManagerCompat.from(ctx)
            .notify(PrayerStripRenderer.NOTIFICATION_ID, renderer.build(day, nextIndex))
        scheduleAlarms(ctx, day)
    }

    /** First cell whose 24h [PrayerCellNative.minutes] is still in the future, else 0 (Fajr). */
    private fun computeNextIndex(day: PrayerStripDay): Int {
        val now = Calendar.getInstance()
        val nowMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        for ((i, cell) in day.cells.withIndex()) {
            if (cell.minutes > nowMinutes) return i
        }
        return 0
    }

    private fun scheduleAlarms(ctx: Context, day: PrayerStripDay) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = Calendar.getInstance().timeInMillis
        for (i in day.cells.indices) {
            val minutes = day.cells[i].minutes
            val triggerCal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, minutes / 60)
                set(Calendar.MINUTE, minutes % 60)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            if (triggerCal.timeInMillis < now) continue
            scheduleExact(
                am, triggerCal.timeInMillis,
                prayerAlarmPI(ctx, i, PrayerAlarmReceiver.REASON_PRAYER)
            )
        }
        val midnight = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_MONTH, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 1)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        scheduleExact(
            am, midnight.timeInMillis,
            prayerAlarmPI(ctx, MIDNIGHT_REQUEST_CODE, PrayerAlarmReceiver.REASON_MIDNIGHT)
        )
    }

    private fun cancelAlarms(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (i in 0..5) am.cancel(prayerAlarmPI(ctx, i, PrayerAlarmReceiver.REASON_PRAYER))
        am.cancel(prayerAlarmPI(ctx, MIDNIGHT_REQUEST_CODE, PrayerAlarmReceiver.REASON_MIDNIGHT))
    }

    private fun prayerAlarmPI(ctx: Context, requestCode: Int, reason: String): PendingIntent {
        val intent = Intent(ctx, PrayerAlarmReceiver::class.java).apply {
            putExtra(PrayerAlarmReceiver.EXTRA_REASON, reason)
        }
        return PendingIntent.getBroadcast(
            ctx, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun scheduleExact(am: AlarmManager, triggerAt: Long, pi: PendingIntent) {
        try {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
        } catch (_: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
        }
    }

    private fun todayKey(): String =
        SimpleDateFormat("dd-MM-yyyy", Locale.US).format(Calendar.getInstance().time)
}

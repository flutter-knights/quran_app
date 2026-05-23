package com.example.quran_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import androidx.core.app.NotificationManagerCompat
import java.util.Calendar

/**
 * Ongoing foreground service that hosts the pinned prayer strip.
 * Plan B does **not** play audio — adhan playback stays on the legacy scheduler.
 * Plan C will extend this service with the AdhanPlayer.
 */
class PrayerStripService : Service() {

    private lateinit var store: PrayerStripStateStore
    private lateinit var renderer: PrayerStripRenderer

    override fun onCreate() {
        super.onCreate()
        store = PrayerStripStateStore(applicationContext)
        renderer = PrayerStripRenderer(applicationContext)
        renderer.ensureChannel()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW_STRIP -> handleShow(intent.getStringExtra(EXTRA_STATE_JSON))
            ACTION_REFRESH_STRIP -> handleRefresh()
            ACTION_HIDE_STRIP -> handleHide()
            else -> handleRefresh()
        }
        return START_STICKY
    }

    private fun handleShow(stateJson: String?) {
        if (stateJson == null) {
            stopSelf()
            return
        }
        store.save(stateJson)
        val state = PrayerStripState.fromJsonString(stateJson)
        val withRecomputedNext = state.copy(nextPrayerIndex = computeNextIndex(state))
        startForeground(
            PrayerStripRenderer.NOTIFICATION_ID,
            renderer.build(withRecomputedNext)
        )
        scheduleAlarms(withRecomputedNext)
    }

    private fun handleRefresh() {
        val state = store.load() ?: run { stopSelf(); return }
        val withRecomputedNext = state.copy(nextPrayerIndex = computeNextIndex(state))
        startForeground(
            PrayerStripRenderer.NOTIFICATION_ID,
            renderer.build(withRecomputedNext)
        )
    }

    private fun handleHide() {
        store.clear()
        cancelAlarms()
        NotificationManagerCompat.from(this)
            .cancel(PrayerStripRenderer.NOTIFICATION_ID)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    /**
     * Re-computes which of the six cells is "next" right now.
     * Returns the index of the first cell whose time > now, or 0 (wrap to Fajr) if all passed.
     * Time strings come in as either ASCII "HH:mm" or Arabic-Indic — we parse digits only.
     */
    private fun computeNextIndex(state: PrayerStripState): Int {
        val now = Calendar.getInstance()
        val nowMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        for ((i, cell) in state.cells.withIndex()) {
            val minutes = parseHHmm(cell.time) ?: continue
            if (minutes > nowMinutes) return i
        }
        return 0
    }

    private fun parseHHmm(raw: String): Int? {
        // Map Arabic-Indic ٠-٩ to 0-9 if present, then parse "HH:mm".
        val ascii = StringBuilder()
        for (ch in raw) {
            ascii.append(
                when (ch) {
                    in '٠'..'٩' -> ('0' + (ch - '٠'))
                    else -> ch
                }
            )
        }
        val parts = ascii.toString().split(':')
        if (parts.size < 2) return null
        val h = parts[0].toIntOrNull() ?: return null
        val m = parts[1].toIntOrNull() ?: return null
        return h * 60 + m
    }

    private fun scheduleAlarms(state: PrayerStripState) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = Calendar.getInstance().timeInMillis

        for (i in state.cells.indices) {
            val minutes = parseHHmm(state.cells[i].time) ?: continue
            val triggerCal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, minutes / 60)
                set(Calendar.MINUTE, minutes % 60)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            if (triggerCal.timeInMillis < now) continue
            val pi = prayerAlarmPI(i, PrayerAlarmReceiver.REASON_PRAYER)
            scheduleExact(alarmManager, triggerCal.timeInMillis, pi)
        }

        val midnight = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_MONTH, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 1)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val piMidnight = prayerAlarmPI(99, PrayerAlarmReceiver.REASON_MIDNIGHT)
        scheduleExact(alarmManager, midnight.timeInMillis, piMidnight)
    }

    private fun cancelAlarms() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (i in 0..5) {
            alarmManager.cancel(prayerAlarmPI(i, PrayerAlarmReceiver.REASON_PRAYER))
        }
        alarmManager.cancel(prayerAlarmPI(99, PrayerAlarmReceiver.REASON_MIDNIGHT))
    }

    private fun prayerAlarmPI(requestCode: Int, reason: String): PendingIntent {
        val intent = Intent(this, PrayerAlarmReceiver::class.java).apply {
            putExtra(PrayerAlarmReceiver.EXTRA_REASON, reason)
        }
        return PendingIntent.getBroadcast(
            this, requestCode, intent,
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

    companion object {
        const val ACTION_SHOW_STRIP = "com.example.quran_app.ACTION_SHOW_STRIP"
        const val ACTION_REFRESH_STRIP = "com.example.quran_app.ACTION_REFRESH_STRIP"
        const val ACTION_HIDE_STRIP = "com.example.quran_app.ACTION_HIDE_STRIP"
        const val EXTRA_STATE_JSON = "state_json"
    }
}

package com.example.quran_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Fired by AlarmManager at each remaining prayer time + midnight. */
class PrayerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val store = PrayerStripStateStore(context)
        if (!store.isEnabled()) return

        val action = intent?.getStringExtra(EXTRA_REASON) ?: REASON_PRAYER

        val serviceIntent = Intent(context, PrayerStripService::class.java).apply {
            this.action = when (action) {
                REASON_MIDNIGHT -> PrayerStripService.ACTION_HIDE_STRIP
                else -> PrayerStripService.ACTION_REFRESH_STRIP
            }
        }
        context.startForegroundService(serviceIntent)
    }

    companion object {
        const val EXTRA_REASON = "reason"
        const val REASON_PRAYER = "prayer"
        const val REASON_MIDNIGHT = "midnight"
    }
}

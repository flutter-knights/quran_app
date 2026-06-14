package com.example.quran_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Fired by AlarmManager at each remaining prayer time + one minute past
 * midnight. Both reasons simply re-render the current day: a prayer-time alarm
 * advances the highlight; the midnight alarm rolls the strip onto the new day
 * (or clears it if the cached window is exhausted).
 */
class PrayerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val store = PrayerStripStateStore(context)
        if (!store.isEnabled()) return
        PrayerStripController.refresh(context)
    }

    companion object {
        const val EXTRA_REASON = "reason"
        const val REASON_PRAYER = "prayer"
        const val REASON_MIDNIGHT = "midnight"
    }
}

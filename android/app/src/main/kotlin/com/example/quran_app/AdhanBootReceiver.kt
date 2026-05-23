package com.example.quran_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Reserved boot receiver for the adhan path. Per spec, we deliberately do
 * NOT re-arm adhan alarms after reboot — the next app launch will re-arm via
 * DailyPrayerContextLoaded → SyncDailyAdhans. Declared in the manifest only so
 * future work can plug in here without an additional manifest change.
 */
class AdhanBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        Log.i(TAG, "onReceive ${intent?.action} — no-op (reserved)")
    }

    companion object {
        private const val TAG = "Adhan"
    }
}

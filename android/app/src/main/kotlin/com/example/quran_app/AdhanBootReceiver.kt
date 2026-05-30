package com.example.quran_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Re-arms adhan and reminder alarms from their persisted snapshots whenever the
 * basis those alarms were scheduled against may have changed. Registered in the
 * manifest for BOOT_COMPLETED, MY_PACKAGE_REPLACED (reboot / app update) and
 * TIMEZONE_CHANGED / TIME_SET (travel / DST / manual clock change, so alarms
 * fire at the correct local wall-clock time — H3). Re-arming is idempotent and
 * `armDays` skips past triggers, so firing on any of these is safe.
 */
class AdhanBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        Log.i(TAG, "onReceive ${intent?.action} — re-arming from snapshots")

        try {
            AdhanScheduler.rearmFromSnapshot(context)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to re-arm adhan alarms from snapshot", e)
        }

        try {
            PrayerReminderScheduler.rearmFromSnapshot(context)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to re-arm reminder alarms from snapshot", e)
        }
    }

    companion object {
        private const val TAG = "Adhan"
    }
}

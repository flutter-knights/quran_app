package com.example.quran_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Boot/package-replace receiver that re-arms adhan and reminder alarms from
 * their persisted snapshots. Registered in the manifest for
 * BOOT_COMPLETED and MY_PACKAGE_REPLACED.
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

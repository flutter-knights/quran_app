package com.example.quran_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class ExactAlarmGrantReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        if (!AlertPlanner.rearmOnExactGrant(intent?.action, Build.VERSION.SDK_INT) { ReliabilityReader.canScheduleExact(context) }) return
        Log.i(TAG, "onReceive: exact alarms granted, re-arming from snapshots")
        val pending = goAsync()
        AlertStore.post(context) { ctx ->
            try {
                AdhanScheduler.rearmFromSnapshot(ctx)
                PrayerStripController.refresh(ctx)
            } finally {
                pending.finish()
            }
        }
    }

    companion object {
        private const val TAG = "Adhan"
    }
}

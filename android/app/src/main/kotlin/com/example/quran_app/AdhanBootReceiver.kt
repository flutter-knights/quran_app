package com.example.quran_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AdhanBootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action
        if (action !in HANDLED) return
        Log.i(TAG, "onReceive $action, re-arming from snapshots")
        val pending = goAsync()
        AlertStore.post(context) { ctx ->
            try {
                val now = System.currentTimeMillis()
                when (action) {
                    Intent.ACTION_BOOT_COMPLETED -> AlertStore.setLong(ctx, AlertStore.LAST_BOOT_HANDLED_AT, now)
                    Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED -> AlertStore.setLong(ctx, AlertStore.LAST_CLOCK_CHANGE_AT, now)
                    Intent.ACTION_MY_PACKAGE_REPLACED -> AlertStore.setIfUnset(ctx, AlertStore.LAST_CHECKED_AT, now)
                }
                AdhanScheduler.rearmFromSnapshot(ctx)
            } finally {
                pending.finish()
            }
        }
    }

    companion object {
        private const val TAG = "Adhan"
        private val HANDLED = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
        )
    }
}

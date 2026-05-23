package com.example.quran_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Fires at prayer time. Must return within 10s (Android limit on BroadcastReceiver).
 * Hands off immediately to AdhanPlaybackService.
 */
class AdhanAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        val prayer = intent?.getStringExtra(EXTRA_PRAYER) ?: "unknown"
        val clip = intent?.getStringExtra(EXTRA_CLIP) ?: "normal_adhan"
        val localeCode = intent?.getStringExtra(EXTRA_LOCALE) ?: "en"

        Log.i(TAG, "onReceive prayer=$prayer clip=$clip locale=$localeCode")

        val serviceIntent = Intent(context, AdhanPlaybackService::class.java).apply {
            action = AdhanPlaybackService.ACTION_PLAY
            putExtra(AdhanPlaybackService.EXTRA_PRAYER, prayer)
            putExtra(AdhanPlaybackService.EXTRA_CLIP, clip)
            putExtra(AdhanPlaybackService.EXTRA_LOCALE, localeCode)
        }
        context.startForegroundService(serviceIntent)
    }

    companion object {
        private const val TAG = "AdhanReceiver"
        const val EXTRA_PRAYER = "prayer"
        const val EXTRA_CLIP = "clip"
        const val EXTRA_LOCALE = "locale"
    }
}

package com.example.quran_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Re-posts the prayer strip after device boot if the user had it enabled. */
class PrayerStripBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val store = PrayerStripStateStore(context)
        if (!store.isEnabled()) return
        PrayerStripController.refresh(context)
    }
}

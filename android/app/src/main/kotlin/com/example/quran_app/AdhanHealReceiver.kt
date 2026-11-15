package com.example.quran_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AdhanHealReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        val pending = goAsync()
        AlertStore.post(context) {
            try {
                AdhanScheduler.rearmFromSnapshot(it)
            } finally {
                pending.finish()
            }
        }
    }
}

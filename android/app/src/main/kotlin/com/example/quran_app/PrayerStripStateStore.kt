package com.example.quran_app

import android.content.Context

/** Wraps SharedPreferences for the prayer-strip cached state JSON. */
class PrayerStripStateStore(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences(
        PREFS_NAME, Context.MODE_PRIVATE
    )

    fun save(stateJson: String) {
        prefs.edit()
            .putBoolean(KEY_ENABLED, true)
            .putString(KEY_STATE_JSON, stateJson)
            .apply()
    }

    fun load(): PrayerStripState? {
        if (!prefs.getBoolean(KEY_ENABLED, false)) return null
        val raw = prefs.getString(KEY_STATE_JSON, null) ?: return null
        return runCatching { PrayerStripState.fromJsonString(raw) }.getOrNull()
    }

    fun clear() {
        prefs.edit()
            .putBoolean(KEY_ENABLED, false)
            .remove(KEY_STATE_JSON)
            .apply()
    }

    fun isEnabled(): Boolean = prefs.getBoolean(KEY_ENABLED, false)

    companion object {
        private const val PREFS_NAME = "prayer_strip_prefs"
        private const val KEY_ENABLED = "enabled"
        private const val KEY_STATE_JSON = "state_json"
    }
}

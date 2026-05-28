package com.example.quran_app

import org.json.JSONObject

data class PrayerCellNative(val label: String, val time: String)

data class PrayerStripState(
    val cells: List<PrayerCellNative>,
    val nextPrayerIndex: Int,
    val hijriDateLabel: String,
    val weekdayLabel: String,
    val localeCode: String,
    val isFriday: Boolean,
    /**
     * ARGB color for the next-prayer pill, supplied by the app's palette as a
     * `#AARRGGBB` hex string. `null` when absent — the renderer then falls back
     * to its own `strip_accent` resource.
     */
    val accentColor: Int? = null
) {
    companion object {
        fun fromJsonString(raw: String): PrayerStripState {
            val obj = JSONObject(raw)
            val rawCells = obj.getJSONArray("cells")
            val cells = mutableListOf<PrayerCellNative>()
            for (i in 0 until rawCells.length()) {
                val c = rawCells.getJSONObject(i)
                cells += PrayerCellNative(c.getString("label"), c.getString("time"))
            }
            val accent = if (obj.has("accentColor")) {
                try {
                    android.graphics.Color.parseColor(obj.getString("accentColor"))
                } catch (e: IllegalArgumentException) {
                    null
                }
            } else {
                null
            }
            return PrayerStripState(
                cells = cells,
                nextPrayerIndex = obj.getInt("nextPrayerIndex"),
                hijriDateLabel = obj.getString("hijriDateLabel"),
                weekdayLabel = if (obj.has("weekdayLabel")) obj.getString("weekdayLabel") else "",
                localeCode = obj.getString("localeCode"),
                isFriday = obj.getBoolean("isFriday"),
                accentColor = accent
            )
        }
    }

    fun toJsonString(): String {
        val obj = JSONObject()
        val arr = org.json.JSONArray()
        for (c in cells) {
            arr.put(JSONObject().put("label", c.label).put("time", c.time))
        }
        obj.put("cells", arr)
        obj.put("nextPrayerIndex", nextPrayerIndex)
        obj.put("hijriDateLabel", hijriDateLabel)
        obj.put("weekdayLabel", weekdayLabel)
        obj.put("localeCode", localeCode)
        obj.put("isFriday", isFriday)
        accentColor?.let {
            // Re-serialize as #AARRGGBB so a round-trip through the state store
            // (boot re-arm) preserves the color.
            obj.put("accentColor", String.format("#%08X", it))
        }
        return obj.toString()
    }
}

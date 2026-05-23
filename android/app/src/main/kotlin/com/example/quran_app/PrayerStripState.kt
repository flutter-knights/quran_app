package com.example.quran_app

import org.json.JSONObject

data class PrayerCellNative(val label: String, val time: String)

data class PrayerStripState(
    val cells: List<PrayerCellNative>,
    val nextPrayerIndex: Int,
    val hijriDateLabel: String,
    val localeCode: String,
    val isFriday: Boolean
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
            return PrayerStripState(
                cells = cells,
                nextPrayerIndex = obj.getInt("nextPrayerIndex"),
                hijriDateLabel = obj.getString("hijriDateLabel"),
                localeCode = obj.getString("localeCode"),
                isFriday = obj.getBoolean("isFriday")
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
        obj.put("localeCode", localeCode)
        obj.put("isFriday", isFriday)
        return obj.toString()
    }
}

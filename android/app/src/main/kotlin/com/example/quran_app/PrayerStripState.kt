package com.example.quran_app

import org.json.JSONArray
import org.json.JSONObject

data class PrayerCellNative(val label: String, val time: String, val minutes: Int)

data class PrayerStripDay(
    val dateKey: String,
    val cells: List<PrayerCellNative>,
    val hijriDateLabel: String,
    val weekdayLabel: String,
    val localeCode: String,
    val isFriday: Boolean,
    /** ARGB for the next-prayer pill; null → renderer falls back to strip_accent. */
    val accentColor: Int? = null,
)

/** A bounded window of consecutive day-states. The renderer shows whichever
 *  day matches the current calendar date. */
data class PrayerStripWindow(val days: List<PrayerStripDay>) {

    companion object {
        fun fromJsonString(raw: String): PrayerStripWindow {
            val obj = JSONObject(raw)
            val daysArr = obj.getJSONArray("days")
            val days = mutableListOf<PrayerStripDay>()
            for (i in 0 until daysArr.length()) {
                days += dayFromJson(daysArr.getJSONObject(i))
            }
            return PrayerStripWindow(days)
        }

        private fun dayFromJson(obj: JSONObject): PrayerStripDay {
            val rawCells = obj.getJSONArray("cells")
            val cells = mutableListOf<PrayerCellNative>()
            for (i in 0 until rawCells.length()) {
                val c = rawCells.getJSONObject(i)
                cells += PrayerCellNative(
                    c.getString("label"),
                    c.getString("time"),
                    c.getInt("minutes"),
                )
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
            return PrayerStripDay(
                dateKey = obj.getString("dateKey"),
                cells = cells,
                hijriDateLabel = obj.getString("hijriDateLabel"),
                weekdayLabel = if (obj.has("weekdayLabel")) obj.getString("weekdayLabel") else "",
                localeCode = obj.getString("localeCode"),
                isFriday = obj.getBoolean("isFriday"),
                accentColor = accent,
            )
        }
    }

    fun toJsonString(): String {
        val obj = JSONObject()
        val daysArr = JSONArray()
        for (d in days) {
            val dObj = JSONObject()
            val cellsArr = JSONArray()
            for (c in d.cells) {
                cellsArr.put(
                    JSONObject()
                        .put("label", c.label)
                        .put("time", c.time)
                        .put("minutes", c.minutes)
                )
            }
            dObj.put("dateKey", d.dateKey)
            dObj.put("cells", cellsArr)
            dObj.put("hijriDateLabel", d.hijriDateLabel)
            dObj.put("weekdayLabel", d.weekdayLabel)
            dObj.put("localeCode", d.localeCode)
            dObj.put("isFriday", d.isFriday)
            d.accentColor?.let { dObj.put("accentColor", String.format("#%08X", it)) }
            daysArr.put(dObj)
        }
        obj.put("days", daysArr)
        return obj.toString()
    }
}

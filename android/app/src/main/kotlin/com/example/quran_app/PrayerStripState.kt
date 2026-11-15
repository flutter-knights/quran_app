package com.example.quran_app

import kotlin.math.roundToInt
import org.json.JSONObject

data class PrayerCellNative(
    val label: String,
    val time: String,
    val minutes: Int,
    val nextLabel: String = "",
)

data class PrayerStripDay(
    val dateKey: String,
    val cells: List<PrayerCellNative>,
    val hijriDateLabel: String,
    val weekdayLabel: String,
    val localeCode: String,
    val isFriday: Boolean,
    val nextTag: String = "",
)

data class StripStyleNative(
    val expanded: Boolean = true,
    val countdown: Boolean = true,
    val highlightDay: Int = 0xFF2E5244.toInt(),
    val highlightNight: Int = 0xFF93BAA8.toInt(),
    val pillTextDay: Int = 0xFFFFFFFF.toInt(),
    val pillTextNight: Int = 0xFF121413.toInt(),
    val backgroundDay: Int? = null,
    val backgroundNight: Int? = null,
    val shape: String = "rounded",
) {
    fun fillsCell(tintable: Boolean) =
        shape == "rounded" || shape == "pill" || (shape == "outline" && !tintable)

    fun highlight(night: Boolean) = if (night) highlightNight else highlightDay

    fun background(night: Boolean) = if (night) backgroundNight else backgroundDay

    fun nextTextColor(night: Boolean, tintable: Boolean = true) =
        if (fillsCell(tintable)) (if (night) pillTextNight else pillTextDay) else highlight(night)

    fun mutedText(night: Boolean, default: Int) =
        if (!night && backgroundDay != null) MUTED_ON_DAY_FILL else default

    companion object {
        val SHAPES = setOf("none", "rounded", "pill", "outline")
        const val MUTED_ON_DAY_FILL = 0xA8000000.toInt()

        fun passed(color: Int): Int {
            val alpha = ((color ushr 24) * 0.6f).roundToInt()
            return (alpha shl 24) or (color and 0x00FFFFFF)
        }
    }
}

data class PrayerStripWindow(
    val days: List<PrayerStripDay>,
    val style: StripStyleNative = StripStyleNative(),
) {

    companion object {
        fun fromJsonString(raw: String): PrayerStripWindow {
            val obj = JSONObject(raw)
            val daysArr = obj.getJSONArray("days")
            val days = (0 until daysArr.length()).map { dayFromJson(daysArr.getJSONObject(it)) }
            return PrayerStripWindow(days, styleFromJson(obj.optJSONObject("style")))
        }

        fun channelArgsToJson(args: Any?): String? {
            if (args !is Map<*, *>) return null
            val json = runCatching { JSONObject(args).toString() }.getOrNull() ?: return null
            return json.takeIf { runCatching { fromJsonString(it) }.isSuccess }
        }

        fun parseArgb(hex: String?): Int? {
            val digits = hex?.removePrefix("#") ?: return null
            if (digits.length != 8) return null
            return runCatching { java.lang.Long.parseLong(digits, 16).toInt() }.getOrNull()
        }

        private fun dayFromJson(obj: JSONObject): PrayerStripDay {
            val rawCells = obj.getJSONArray("cells")
            val cells = (0 until rawCells.length()).map {
                val c = rawCells.getJSONObject(it)
                PrayerCellNative(
                    c.getString("label"),
                    c.getString("time"),
                    c.getInt("minutes"),
                    c.optString("nextLabel", ""),
                )
            }
            return PrayerStripDay(
                dateKey = obj.getString("dateKey"),
                cells = cells,
                hijriDateLabel = obj.getString("hijriDateLabel"),
                weekdayLabel = obj.optString("weekdayLabel", ""),
                localeCode = obj.getString("localeCode"),
                isFriday = obj.getBoolean("isFriday"),
                nextTag = obj.optString("nextTag", ""),
            )
        }

        private fun styleFromJson(obj: JSONObject?): StripStyleNative {
            val d = StripStyleNative()
            if (obj == null) return d
            fun color(key: String) = if (obj.has(key)) parseArgb(obj.optString(key)) else null
            return StripStyleNative(
                expanded = obj.optBoolean("expanded", d.expanded),
                countdown = obj.optBoolean("countdown", d.countdown),
                highlightDay = color("highlightDay") ?: d.highlightDay,
                highlightNight = color("highlightNight") ?: d.highlightNight,
                pillTextDay = color("pillTextDay") ?: d.pillTextDay,
                pillTextNight = color("pillTextNight") ?: d.pillTextNight,
                backgroundDay = color("backgroundDay"),
                backgroundNight = color("backgroundNight"),
                shape = obj.optString("shape", d.shape).takeIf { it in StripStyleNative.SHAPES } ?: d.shape,
            )
        }
    }
}

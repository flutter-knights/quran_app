package com.example.quran_app

import org.json.JSONObject

data class PrayerCellNative(
    val label: String,
    val time: String,
    val minutes: Int,
    val nextLabel: String = "",
    val timeFull: String = time,
)

data class PrayerStripDay(
    val dateKey: String,
    val cells: List<PrayerCellNative>,
    val hijriDateLabel: String,
    val weekdayLabel: String,
    val localeCode: String,
    val isFriday: Boolean,
)

enum class StripShape(val wire: String) {
    NONE("none"),
    ROUNDED("rounded"),
    PILL("pill"),
    OUTLINE("outline");

    companion object {
        fun parse(wire: String?) = entries.firstOrNull { it.wire == wire } ?: ROUNDED
    }
}

enum class StripCellRole {
    PASSED,
    NEXT,
    UPCOMING;

    companion object {
        fun of(index: Int, nextIndex: Int) = when {
            index == nextIndex -> NEXT
            nextIndex < 0 || index < nextIndex -> PASSED
            else -> UPCOMING
        }
    }
}

data class StripStyleNative(
    val expanded: Boolean = true,
    val countdown: Boolean = true,
    val highlightDay: Int = 0xFF2E5244.toInt(),
    val highlightNight: Int = 0xFF93BAA8.toInt(),
    val highlightTextDay: Int = 0xFF2E5244.toInt(),
    val pillTextDay: Int = 0xFFFFFFFF.toInt(),
    val pillTextNight: Int = 0xFF121413.toInt(),
    val backgroundDay: Int? = null,
    val backgroundNight: Int? = null,
    val shape: StripShape = StripShape.ROUNDED,
) {
    fun fillsCell(tintable: Boolean) =
        shape == StripShape.ROUNDED || shape == StripShape.PILL || (shape == StripShape.OUTLINE && !tintable)

    fun highlight(night: Boolean) = if (night) highlightNight else highlightDay

    fun background(night: Boolean) = if (night) backgroundNight else backgroundDay

    fun nextTextColor(night: Boolean, tintable: Boolean = true) = when {
        fillsCell(tintable) -> if (night) pillTextNight else pillTextDay
        night -> highlightNight
        else -> highlightTextDay
    }

    fun resolvesCellTextAtRender(tintable: Boolean) =
        !tintable && (backgroundDay != null || backgroundNight != null)

    fun mutedText(night: Boolean, default: Int) =
        if (!night && backgroundDay != null) MUTED_ON_DAY_FILL else default

    companion object {
        const val MUTED_ON_DAY_FILL = 0xA8000000.toInt()
    }
}

data class PrayerStripWindow(
    val days: List<PrayerStripDay>,
    val style: StripStyleNative = StripStyleNative(),
    val nextTag: String = "",
) {

    companion object {
        fun fromJsonString(raw: String): PrayerStripWindow {
            val obj = JSONObject(raw)
            val daysArr = obj.getJSONArray("days")
            val days = (0 until daysArr.length()).map { dayFromJson(daysArr.getJSONObject(it)) }
            val legacyTag = daysArr.optJSONObject(0)?.optString("nextTag", "") ?: ""
            return PrayerStripWindow(
                days,
                styleFromJson(obj.optJSONObject("style")),
                obj.optString("nextTag", legacyTag),
            )
        }

        fun parseOrNull(raw: String?): PrayerStripWindow? =
            raw?.let { runCatching { fromJsonString(it) }.getOrNull() }

        fun channelArgsToJson(args: Any?): String? {
            if (args !is Map<*, *>) return null
            val json = runCatching { JSONObject(args).toString() }.getOrNull() ?: return null
            return json.takeIf { parseOrNull(it) != null }
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
                val time = c.getString("time")
                PrayerCellNative(
                    label = c.getString("label"),
                    time = time,
                    minutes = c.getInt("minutes"),
                    nextLabel = c.optString("nextLabel", ""),
                    timeFull = c.optString("timeFull", time),
                )
            }
            return PrayerStripDay(
                dateKey = obj.getString("dateKey"),
                cells = cells,
                hijriDateLabel = obj.getString("hijriDateLabel"),
                weekdayLabel = obj.optString("weekdayLabel", ""),
                localeCode = obj.getString("localeCode"),
                isFriday = obj.getBoolean("isFriday"),
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
                highlightTextDay = color("highlightTextDay") ?: color("highlightDay") ?: d.highlightTextDay,
                pillTextDay = color("pillTextDay") ?: d.pillTextDay,
                pillTextNight = color("pillTextNight") ?: d.pillTextNight,
                backgroundDay = color("backgroundDay"),
                backgroundNight = color("backgroundNight"),
                shape = StripShape.parse(obj.optString("shape", StripShape.ROUNDED.wire)),
            )
        }
    }
}

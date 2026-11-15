package com.example.quran_app

import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone
import kotlin.math.abs

object AlertPlanner {

    const val MAX_DAYS = 7
    const val ADHAN_BASE = 200
    const val REMINDER_BASE = 300
    const val HEAL_REQUEST_CODE = 298
    const val TEST_REQUEST_CODE = 299
    const val LATE_THRESHOLD_MS = 30 * 60_000L
    const val CLOCK_DRIFT_MS = 2 * 60_000L
    const val MISS_MARGIN_MS = 35 * 60_000L
    const val REACH_MS = 24 * 60 * 60_000L
    const val PRUNE_MS = 48 * 60 * 60_000L
    const val ISHA_FALLBACK_MS = 6 * 60 * 60_000L
    val PRAYERS = listOf("fajr", "dhuhr", "asr", "maghrib", "isha")

    private val CANONICAL = listOf("fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha")
    private val DATE = Regex("""(\d{4})-(\d{2})-(\d{2})""")
    private val TIME = Regex("""(\d{1,2}):(\d{2})""")

    data class Day(val date: String, val timings: Map<String, String>)
    data class AdhanSpec(val sound: String, val ringInSilent: Boolean)
    data class ReminderSpec(val minutes: Int, val reminderSound: String)
    data class AdhanSnapshot(val days: List<Day>, val alerts: Map<String, AdhanSpec>, val localeCode: String, val legacy: Boolean)
    data class ReminderSnapshot(val days: List<Day>, val reminders: Map<String, ReminderSpec>, val localeCode: String, val legacy: Boolean)
    data class PlannedAlarm(val key: String, val prayer: String, val requestCode: Int, val triggerAt: Long, val prayerAt: Long, val nextAt: Long)
    data class ArmedEntry(val triggerAt: Long, val armedAt: Long)
    data class Record(val outcome: Outcome, val triggerAt: Long)
    data class Miss(val prayer: String, val at: Long)

    enum class Outcome { FIRED, LATE, SKIPPED, MISSED }
    enum class Route { SKIP, LATE, MISSED, DELIVER }

    fun key(date: String, prayer: String) = "$date/$prayer"

    fun keyFor(triggerAt: Long, prayer: String, zone: TimeZone): String {
        val c = Calendar.getInstance(zone).apply { timeInMillis = triggerAt }
        val date = String.format(Locale.US, "%04d-%02d-%02d", c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH))
        return key(date, prayer)
    }

    fun prayerAt(day: Day, prayer: String, zone: TimeZone): Long? {
        val d = DATE.matchEntire(day.date) ?: return null
        val t = TIME.matchEntire(day.timings[prayer] ?: return null) ?: return null
        val (year, month, dom) = d.destructured
        val (h, m) = t.destructured
        val hour = h.toInt()
        val minute = m.toInt()
        if (hour > 23 || minute > 59) return null
        return try {
            Calendar.getInstance(zone).apply {
                isLenient = false
                clear()
                set(year.toInt(), month.toInt() - 1, dom.toInt(), hour, minute, 0)
            }.timeInMillis
        } catch (e: IllegalArgumentException) {
            null
        }
    }

    fun planAdhans(days: List<Day>, alerts: Map<String, AdhanSpec>, now: Long, zone: TimeZone): List<PlannedAlarm> {
        val sorted = days.distinctBy { it.date }.sortedBy { it.date }
        val chosen = sorted.filter { d -> PRAYERS.any { p -> alerts.containsKey(p) && (prayerAt(d, p, zone) ?: 0L) > now } }
            .take(MAX_DAYS)
        return chosen.flatMapIndexed { slot, d ->
            PRAYERS.mapIndexedNotNull { i, p ->
                val at = prayerAt(d, p, zone)
                if (!alerts.containsKey(p) || at == null || at <= now) null
                else PlannedAlarm(key(d.date, p), p, ADHAN_BASE + slot * 10 + i, at, at, nextAt(sorted, d, p, at, zone))
            }
        }
    }

    fun planReminders(days: List<Day>, reminders: Map<String, ReminderSpec>, now: Long, zone: TimeZone): List<PlannedAlarm> {
        val valid = reminders.filterValues { it.minutes > 0 }
        fun trigger(d: Day, p: String): Pair<Long, Long>? {
            val spec = valid[p] ?: return null
            val at = prayerAt(d, p, zone) ?: return null
            return (at - spec.minutes * 60_000L) to at
        }
        val sorted = days.distinctBy { it.date }.sortedBy { it.date }
        val chosen = sorted.filter { d -> PRAYERS.any { p -> (trigger(d, p)?.first ?: 0L) > now } }.take(MAX_DAYS)
        return chosen.flatMapIndexed { slot, d ->
            PRAYERS.mapIndexedNotNull { i, p ->
                val (at, prayerTime) = trigger(d, p) ?: return@mapIndexedNotNull null
                if (at <= now) null
                else PlannedAlarm(key(d.date, p), p, REMINDER_BASE + slot * 10 + i, at, prayerTime, prayerTime)
            }
        }
    }

    private fun nextAt(sorted: List<Day>, d: Day, p: String, at: Long, zone: TimeZone): Long {
        val later = CANONICAL.drop(CANONICAL.indexOf(p) + 1).firstNotNullOfOrNull { prayerAt(d, it, zone) }
        if (later != null) return later
        val tomorrow = sorted.getOrNull(sorted.indexOf(d) + 1)?.let { prayerAt(it, "fajr", zone) }
        return tomorrow?.takeIf { it > at && it - at < REACH_MS } ?: (at + ISHA_FALLBACK_MS)
    }

    fun staleRequestCodes(base: Int, armed: Set<Int>) =
        (0 until MAX_DAYS).flatMap { slot -> PRAYERS.indices.map { base + slot * 10 + it } }.filter { it !in armed }

    fun clockMoved(nowWall: Long, nowElapsed: Long, armedAt: Long?, armedElapsed: Long?): Boolean {
        if (armedAt == null || armedElapsed == null || nowElapsed < armedElapsed) return false
        return abs((nowWall - armedAt) - (nowElapsed - armedElapsed)) > CLOCK_DRIFT_MS
    }

    fun route(
        notificationsEnabled: Boolean, channelBlocked: Boolean, nowWall: Long, nowElapsed: Long,
        triggerAt: Long, nextAt: Long?, armedAt: Long?, armedElapsed: Long?,
    ): Route {
        if (!notificationsEnabled || channelBlocked) return Route.SKIP
        if (nowWall - triggerAt <= LATE_THRESHOLD_MS) return Route.DELIVER
        if (clockMoved(nowWall, nowElapsed, armedAt, armedElapsed)) return Route.SKIP
        return if (nowWall < (nextAt ?: (triggerAt + LATE_THRESHOLD_MS))) Route.LATE else Route.MISSED
    }

    fun detectMisses(
        armed: Map<String, ArmedEntry>, records: Map<String, Record>, lastCheckedAt: Long,
        lastBootHandledAt: Long, lastClockChangeAt: Long, now: Long,
    ): List<Miss> {
        val from = maxOf(lastCheckedAt, lastBootHandledAt, lastClockChangeAt, now - REACH_MS)
        val to = now - MISS_MARGIN_MS
        val silent = armed.filter { (k, e) -> e.armedAt < e.triggerAt && e.triggerAt > from && e.triggerAt <= to && k !in records }
            .map { (k, e) -> Miss(k.substringAfter('/'), e.triggerAt) }
        val recorded = records.filter { (_, r) -> r.outcome == Outcome.MISSED && r.triggerAt > lastCheckedAt }
            .map { (k, r) -> Miss(k.substringAfter('/'), r.triggerAt) }
        return (silent + recorded).sortedByDescending { it.at }
    }

    fun lateSince(records: Map<String, Record>, lastCheckedAt: Long) =
        records.filter { (_, r) -> r.outcome == Outcome.LATE && r.triggerAt > lastCheckedAt }
            .map { (k, r) -> Miss(k.substringAfter('/'), r.triggerAt) }
            .sortedByDescending { it.at }

    fun pruneArmed(armed: Map<String, ArmedEntry>, now: Long) = armed.filterValues { it.triggerAt >= now - PRUNE_MS }

    fun pruneRecords(records: Map<String, Record>, now: Long) = records.filterValues { it.triggerAt >= now - PRUNE_MS }

    fun snapshotUntil(days: List<Day>) = days.map { it.date }.filter { DATE.matches(it) }.maxOrNull()

    fun parseAdhanSnapshot(json: String): AdhanSnapshot {
        val obj = JSONObject(json)
        val days = parseDays(obj.getJSONArray("days"))
        val alertsObj = obj.optJSONObject("alerts")
        val alerts = if (alertsObj != null) {
            alertsObj.keys().asSequence().mapNotNull { p ->
                val a = alertsObj.optJSONObject(p) ?: return@mapNotNull null
                p to AdhanSpec(a.optString("sound", "adhan"), a.optBoolean("ringInSilent", false))
            }.toMap()
        } else {
            PRAYERS.filter { p -> days.any { it.timings.containsKey(p) } }.associateWith { AdhanSpec("adhan", true) }
        }
        return AdhanSnapshot(days, alerts, obj.optString("locale", "en"), alertsObj == null)
    }

    fun parseReminderSnapshot(json: String): ReminderSnapshot {
        val obj = JSONObject(json)
        val days = parseDays(obj.getJSONArray("days"))
        val remindersObj = obj.optJSONObject("reminders") ?: JSONObject()
        var legacy = false
        val reminders = remindersObj.keys().asSequence().mapNotNull { p ->
            when (val v = remindersObj.get(p)) {
                is Number -> {
                    legacy = true
                    p to ReminderSpec(v.toInt(), "vibrate")
                }
                is JSONObject -> p to ReminderSpec(v.optInt("minutes", 0), v.optString("reminderSound", "vibrate"))
                else -> null
            }
        }.toMap()
        return ReminderSnapshot(days, reminders, obj.optString("locale", "en"), legacy)
    }

    fun encodeAdhanSnapshot(snapshot: AdhanSnapshot): String {
        val alerts = JSONObject()
        for ((p, a) in snapshot.alerts) alerts.put(p, JSONObject().put("sound", a.sound).put("ringInSilent", a.ringInSilent))
        return JSONObject().put("days", encodeDays(snapshot.days)).put("alerts", alerts).put("locale", snapshot.localeCode).toString()
    }

    fun encodeReminderSnapshot(snapshot: ReminderSnapshot): String {
        val reminders = JSONObject()
        for ((p, r) in snapshot.reminders) reminders.put(p, JSONObject().put("minutes", r.minutes).put("reminderSound", r.reminderSound))
        return JSONObject().put("days", encodeDays(snapshot.days)).put("reminders", reminders).put("locale", snapshot.localeCode).toString()
    }

    fun encodeArmed(armed: Map<String, ArmedEntry>): String {
        val obj = JSONObject()
        for ((k, e) in armed) obj.put(k, JSONObject().put("triggerAt", e.triggerAt).put("armedAt", e.armedAt))
        return obj.toString()
    }

    fun decodeArmed(json: String?): Map<String, ArmedEntry> = decodeEntries(json) { e ->
        ArmedEntry(e.getLong("triggerAt"), e.getLong("armedAt"))
    }

    fun encodeRecords(records: Map<String, Record>): String {
        val obj = JSONObject()
        for ((k, r) in records) obj.put(k, JSONObject().put("outcome", r.outcome.name).put("triggerAt", r.triggerAt))
        return obj.toString()
    }

    fun decodeRecords(json: String?): Map<String, Record> = decodeEntries(json) { e ->
        Record(Outcome.valueOf(e.getString("outcome")), e.getLong("triggerAt"))
    }

    private fun <T> decodeEntries(json: String?, read: (JSONObject) -> T): Map<String, T> {
        if (json == null) return emptyMap()
        return try {
            val obj = JSONObject(json)
            obj.keys().asSequence().mapNotNull { k ->
                try {
                    k to read(obj.getJSONObject(k))
                } catch (e: Exception) {
                    null
                }
            }.toMap()
        } catch (e: Exception) {
            emptyMap()
        }
    }

    private fun parseDays(arr: JSONArray) = (0 until arr.length()).mapNotNull { i ->
        val d = arr.optJSONObject(i) ?: return@mapNotNull null
        val date = d.optString("date", "").ifEmpty { return@mapNotNull null }
        val t = d.optJSONObject("timings") ?: JSONObject()
        Day(date, t.keys().asSequence().associateWith { t.optString(it, "") })
    }

    private fun encodeDays(days: List<Day>): JSONArray {
        val arr = JSONArray()
        for (d in days) {
            val t = JSONObject()
            for ((k, v) in d.timings) t.put(k, v)
            arr.put(JSONObject().put("date", d.date).put("timings", t))
        }
        return arr
    }
}

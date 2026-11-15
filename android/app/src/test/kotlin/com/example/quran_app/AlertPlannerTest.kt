package com.example.quran_app

import com.example.quran_app.AlertPlanner.AdhanSnapshot
import com.example.quran_app.AlertPlanner.AdhanSpec
import com.example.quran_app.AlertPlanner.ArmedEntry
import com.example.quran_app.AlertPlanner.Day
import com.example.quran_app.AlertPlanner.Miss
import com.example.quran_app.AlertPlanner.Outcome
import com.example.quran_app.AlertPlanner.PRAYERS
import com.example.quran_app.AlertPlanner.Record
import com.example.quran_app.AlertPlanner.ReminderSnapshot
import com.example.quran_app.AlertPlanner.ReminderSpec
import com.example.quran_app.AlertPlanner.Route
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime
import java.time.ZoneOffset
import java.util.TimeZone

class AlertPlannerTest {

    private val utc = TimeZone.getTimeZone("UTC")

    private fun ms(s: String) = LocalDateTime.parse(s).toInstant(ZoneOffset.UTC).toEpochMilli()

    private fun day(date: String) = Day(
        date,
        mapOf(
            "fajr" to "04:52", "sunrise" to "06:18", "dhuhr" to "11:41",
            "asr" to "14:39", "maghrib" to "16:58", "isha" to "18:16",
        ),
    )

    private val tenDays = (15..24).map { day("2026-11-$it") }

    private val allOn = PRAYERS.associateWith { AdhanSpec("adhan", false) }

    private val trigger = ms("2026-11-15T14:39")
    private val next = ms("2026-11-15T16:58")
    private val armedAt = ms("2026-11-15T09:00")
    private val armedElapsed = 1_000_000L
    private val minute = 60_000L

    private fun elapsedAt(wall: Long) = armedElapsed + (wall - armedAt)

    private fun routeAt(
        nowWall: Long,
        nowElapsed: Long = elapsedAt(nowWall),
        enabled: Boolean = true,
        nextAt: Long? = next,
        armed: Long? = armedAt,
        armedEl: Long? = armedElapsed,
    ) = AlertPlanner.route(enabled, false, nowWall, nowElapsed, trigger, nextAt, armed, armedEl)

    @Test fun planAdhans_armsFirstSevenDatesWithFutureTriggers() {
        val plan = AlertPlanner.planAdhans(tenDays, allOn, ms("2026-11-15T13:00"), utc)
        assertEquals(listOf(202, 203, 204), plan.filter { it.key.startsWith("2026-11-15") }.map { it.requestCode })
        assertEquals((260..264).toList(), plan.filter { it.key.startsWith("2026-11-21") }.map { it.requestCode })
        assertTrue(plan.none { it.key.startsWith("2026-11-22") })
        assertEquals(33, plan.size)
    }

    @Test fun planAdhans_skipsTodayWhenAllPassed() {
        val plan = AlertPlanner.planAdhans(tenDays, allOn, ms("2026-11-15T20:00"), utc)
        assertEquals("2026-11-16/fajr", plan.first().key)
        assertEquals(200, plan.first().requestCode)
    }

    @Test fun planAdhans_nextAtFollowsCanonicalOrder() {
        val alerts = mapOf("fajr" to AdhanSpec("adhan", false), "isha" to AdhanSpec("tone", false))
        val plan = AlertPlanner.planAdhans(tenDays, alerts, ms("2026-11-15T00:00"), utc)
        assertEquals(ms("2026-11-15T06:18"), plan.first { it.key == "2026-11-15/fajr" }.nextAt)
        assertEquals(ms("2026-11-16T04:52"), plan.first { it.key == "2026-11-15/isha" }.nextAt)
    }

    @Test fun planAdhans_lastIshaInSnapshotFallsBackSixHours() {
        val plan = AlertPlanner.planAdhans(listOf(day("2026-11-15")), allOn, ms("2026-11-15T00:00"), utc)
        assertEquals(ms("2026-11-16T00:16"), plan.first { it.prayer == "isha" }.nextAt)
    }

    @Test fun planAdhans_ishaBeforeAGapFallsBackSixHours() {
        val plan = AlertPlanner.planAdhans(listOf(day("2026-11-15"), day("2026-11-18")), allOn, ms("2026-11-15T00:00"), utc)
        assertEquals(ms("2026-11-16T00:16"), plan.first { it.key == "2026-11-15/isha" }.nextAt)
    }

    @Test fun planAdhans_dedupesAndSkipsMalformed() {
        val bad = Day("2026-11-16", mapOf("fajr" to "25:00", "dhuhr" to "5:7x", "asr" to "", "maghrib" to "16:58", "isha" to "18:16"))
        val plan = AlertPlanner.planAdhans(listOf(day("2026-11-15"), day("2026-11-15"), bad), allOn, ms("2026-11-15T20:00"), utc)
        assertEquals(listOf("2026-11-16/maghrib", "2026-11-16/isha"), plan.map { it.key })
    }

    @Test fun planAdhans_emptyAlertsCancelsAllSlots() {
        assertTrue(AlertPlanner.planAdhans(tenDays, emptyMap(), ms("2026-11-15T00:00"), utc).isEmpty())
        assertEquals(35, AlertPlanner.staleRequestCodes(200, emptySet()).size)
        assertFalse(AlertPlanner.staleRequestCodes(200, setOf(202)).contains(202))
    }

    @Test fun prayerAt_rejectsMalformedDateAndTime() {
        assertNull(AlertPlanner.prayerAt(Day("2026-02-30", mapOf("fajr" to "04:52")), "fajr", utc))
        assertNull(AlertPlanner.prayerAt(Day("2026-11-15", mapOf("fajr" to "04:60")), "fajr", utc))
        assertEquals(ms("2026-11-15T04:05"), AlertPlanner.prayerAt(Day("2026-11-15", mapOf("fajr" to "4:05")), "fajr", utc))
    }

    @Test fun keyFor_usesTheLocalDate() {
        assertEquals("2026-11-15/isha", AlertPlanner.keyFor(ms("2026-11-15T18:16"), "isha", utc))
        assertEquals("2026-11-16/isha", AlertPlanner.keyFor(ms("2026-11-15T22:30"), "isha", TimeZone.getTimeZone("GMT+03:00")))
    }

    @Test fun planReminders_subtractsMinutesAndUses300Base() {
        val plan = AlertPlanner.planReminders(tenDays, mapOf("asr" to ReminderSpec(15, "tone")), ms("2026-11-15T13:00"), utc)
        assertEquals(302, plan.first().requestCode)
        assertEquals(ms("2026-11-15T14:24"), plan.first().triggerAt)
        assertEquals(ms("2026-11-15T14:39"), plan.first().prayerAt)
    }

    @Test fun parseAdhanSnapshot_v2() {
        val s = AlertPlanner.parseAdhanSnapshot(
            """{"days":[{"date":"2026-11-15","timings":{"fajr":"04:52"}}],"alerts":{"fajr":{"sound":"tone","ringInSilent":false}},"locale":"ar"}""",
        )
        assertFalse(s.legacy)
        assertEquals(AdhanSpec("tone", false), s.alerts["fajr"])
        assertEquals("ar", s.localeCode)
        assertEquals(listOf(Day("2026-11-15", mapOf("fajr" to "04:52"))), s.days)
    }

    @Test fun parseAdhanSnapshot_legacyClips() {
        val s = AlertPlanner.parseAdhanSnapshot("""{"days":[{"date":"2026-11-15","timings":{"fajr":"04:52","asr":"14:39"}}],"clips":{"fajr":"fajr_adhan","asr":"normal_adhan"},"locale":"ar"}""")
        assertTrue(s.legacy)
        assertEquals(AdhanSpec("adhan", true), s.alerts["fajr"])
        assertEquals(setOf("fajr", "asr"), s.alerts.keys)
    }

    @Test fun adhanSnapshot_roundTripsWithEmptyAlerts() {
        val snapshot = AdhanSnapshot(listOf(day("2026-11-15")), emptyMap(), "en", false)
        val parsed = AlertPlanner.parseAdhanSnapshot(AlertPlanner.encodeAdhanSnapshot(snapshot))
        assertEquals(snapshot, parsed)
    }

    @Test fun reminderSnapshot_roundTrips() {
        val snapshot = ReminderSnapshot(listOf(day("2026-11-15")), mapOf("asr" to ReminderSpec(15, "tone")), "ar", false)
        assertEquals(snapshot, AlertPlanner.parseReminderSnapshot(AlertPlanner.encodeReminderSnapshot(snapshot)))
    }

    @Test fun parseReminderSnapshot_legacyIntsBecomeVibrate() {
        val s = AlertPlanner.parseReminderSnapshot("""{"days":[],"reminders":{"asr":10},"locale":"en"}""")
        assertEquals(ReminderSpec(10, "vibrate"), s.reminders["asr"])
        assertTrue(s.legacy)
    }

    @Test(expected = Exception::class) fun parseAdhanSnapshot_malformedThrows() {
        AlertPlanner.parseAdhanSnapshot("{not json")
    }

    @Test fun armedAndRecords_roundTrip() {
        val armed = mapOf("2026-11-15/asr" to ArmedEntry(trigger, armedAt))
        val records = mapOf("2026-11-15/asr" to Record(Outcome.LATE, trigger))
        assertEquals(armed, AlertPlanner.decodeArmed(AlertPlanner.encodeArmed(armed)))
        assertEquals(records, AlertPlanner.decodeRecords(AlertPlanner.encodeRecords(records)))
        assertTrue(AlertPlanner.decodeArmed("{oops").isEmpty())
        assertTrue(AlertPlanner.decodeRecords(null).isEmpty())
    }

    @Test fun route_onTimeDelivers() {
        assertEquals(Route.DELIVER, routeAt(trigger + 29 * minute))
    }

    @Test fun route_notificationsOffSkips() {
        assertEquals(Route.SKIP, routeAt(trigger, enabled = false))
    }

    @Test fun route_skipsWhenClockMovedAfterArming() {
        val nowWall = trigger + 40 * minute
        assertEquals(Route.SKIP, routeAt(nowWall, nowElapsed = elapsedAt(trigger) + 5 * minute))
    }

    @Test fun route_lateBeforeNextAt() {
        assertEquals(Route.LATE, routeAt(ms("2026-11-15T15:10")))
    }

    @Test fun route_missedAfterNextAt() {
        assertEquals(Route.MISSED, routeAt(ms("2026-11-15T17:00")))
    }

    @Test fun route_legacyExtrasLateIsMissed() {
        val nowWall = trigger + 31 * minute
        assertEquals(Route.MISSED, routeAt(nowWall, nowElapsed = 5_000L, nextAt = null, armed = null, armedEl = null))
    }

    @Test fun clockMoved_ignoresRebootSinceArming() {
        assertFalse(AlertPlanner.clockMoved(trigger + 40 * minute, armedElapsed - 1, armedAt, armedElapsed))
    }

    @Test fun detectMisses_reportsUnrecordedIshaNextMorning() {
        val armed = mapOf("2026-11-14/isha" to ArmedEntry(ms("2026-11-14T18:16"), ms("2026-11-14T09:00")))
        val misses = AlertPlanner.detectMisses(armed, emptyMap(), 0, 0, 0, ms("2026-11-15T07:00"))
        assertEquals(listOf(Miss("isha", ms("2026-11-14T18:16"))), misses)
    }

    @Test fun detectMisses_skipsRecordedArmedAfterTriggerAndRecent() {
        val now = ms("2026-11-15T17:00")
        val armed = mapOf("2026-11-15/asr" to ArmedEntry(trigger, armedAt))
        assertTrue(AlertPlanner.detectMisses(armed, mapOf("2026-11-15/asr" to Record(Outcome.FIRED, trigger)), 0, 0, 0, now).isEmpty())
        assertTrue(AlertPlanner.detectMisses(armed, mapOf("2026-11-15/asr" to Record(Outcome.SKIPPED, trigger)), 0, 0, 0, now).isEmpty())
        val armedLate = mapOf("2026-11-15/asr" to ArmedEntry(trigger, trigger + minute))
        assertTrue(AlertPlanner.detectMisses(armedLate, emptyMap(), 0, 0, 0, now).isEmpty())
        assertTrue(AlertPlanner.detectMisses(armed, emptyMap(), 0, 0, 0, trigger + 20 * minute).isEmpty())
    }

    @Test fun detectMisses_ignoresTriggersBeforeBoot() {
        val armed = mapOf("2026-11-15/asr" to ArmedEntry(trigger, armedAt))
        assertTrue(AlertPlanner.detectMisses(armed, emptyMap(), 0, trigger + minute, 0, ms("2026-11-15T17:00")).isEmpty())
    }

    @Test fun detectMisses_ignoresTriggersBeforeClockChange() {
        val armed = mapOf("2026-11-15/asr" to ArmedEntry(trigger, armedAt))
        assertTrue(AlertPlanner.detectMisses(armed, emptyMap(), 0, 0, trigger + minute, ms("2026-11-15T17:00")).isEmpty())
    }

    @Test fun detectMisses_includesRecordedMissedAfterLastChecked() {
        val records = mapOf("2026-11-15/asr" to Record(Outcome.MISSED, trigger))
        val now = ms("2026-11-15T17:00")
        assertEquals(listOf(Miss("asr", trigger)), AlertPlanner.detectMisses(emptyMap(), records, trigger - minute, 0, 0, now))
        assertTrue(AlertPlanner.detectMisses(emptyMap(), records, trigger, 0, 0, now).isEmpty())
    }

    @Test fun lateSince_filtersByLastChecked() {
        val records = mapOf(
            "2026-11-15/dhuhr" to Record(Outcome.LATE, ms("2026-11-15T11:41")),
            "2026-11-15/asr" to Record(Outcome.LATE, trigger),
            "2026-11-15/maghrib" to Record(Outcome.FIRED, next),
        )
        assertEquals(listOf(Miss("asr", trigger)), AlertPlanner.lateSince(records, ms("2026-11-15T12:00")))
        assertEquals(listOf(Miss("asr", trigger), Miss("dhuhr", ms("2026-11-15T11:41"))), AlertPlanner.lateSince(records, 0))
    }

    @Test fun prune_drops48hOld() {
        val now = ms("2026-11-17T15:00")
        val armed = mapOf(
            "2026-11-15/asr" to ArmedEntry(trigger, armedAt),
            "2026-11-15/maghrib" to ArmedEntry(next, armedAt),
        )
        assertEquals(setOf("2026-11-15/maghrib"), AlertPlanner.pruneArmed(armed, now).keys)
        val records = mapOf(
            "2026-11-15/asr" to Record(Outcome.FIRED, trigger),
            "2026-11-15/maghrib" to Record(Outcome.FIRED, next),
        )
        assertEquals(setOf("2026-11-15/maghrib"), AlertPlanner.pruneRecords(records, now).keys)
    }

    @Test fun snapshotUntil_isTheLastValidDate() {
        assertEquals("2026-11-24", AlertPlanner.snapshotUntil(tenDays.reversed() + Day("bad", emptyMap())))
        assertNull(AlertPlanner.snapshotUntil(emptyList()))
    }
}

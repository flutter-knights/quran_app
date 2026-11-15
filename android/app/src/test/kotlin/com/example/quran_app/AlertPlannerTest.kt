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
import com.example.quran_app.AlertPlanner.Slot
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
        assertEquals(listOf(242, 243, 244), plan.filter { it.key.startsWith("2026-11-15") }.map { it.requestCode })
        assertEquals((220..224).toList(), plan.filter { it.key.startsWith("2026-11-21") }.map { it.requestCode })
        assertTrue(plan.none { it.key.startsWith("2026-11-22") })
        assertEquals(33, plan.size)
    }

    @Test fun planAdhans_skipsTodayWhenAllPassed() {
        val plan = AlertPlanner.planAdhans(tenDays, allOn, ms("2026-11-15T20:00"), utc)
        assertEquals("2026-11-16/fajr", plan.first().key)
        assertEquals(250, plan.first().requestCode)
        assertEquals("2026-11-22/isha", plan.last().key)
        assertEquals(234, plan.last().requestCode)
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
        assertEquals(40, AlertPlanner.staleRequestCodes(200, emptySet()).size)
        assertFalse(AlertPlanner.staleRequestCodes(200, setOf(202)).contains(202))
    }

    @Test fun prayerAt_rejectsMalformedDateAndTime() {
        assertNull(AlertPlanner.prayerAt(Day("2026-02-30", mapOf("fajr" to "04:52")), "fajr", utc))
        assertNull(AlertPlanner.prayerAt(Day("2026-11-15", mapOf("fajr" to "04:60")), "fajr", utc))
        assertEquals(ms("2026-11-15T04:05"), AlertPlanner.prayerAt(Day("2026-11-15", mapOf("fajr" to "4:05")), "fajr", utc))
    }

    private fun local(s: String, hours: Int) = LocalDateTime.parse(s).toInstant(ZoneOffset.ofHours(hours)).toEpochMilli()

    private val riyadh = TimeZone.getTimeZone("GMT+03:00")
    private val newYork = TimeZone.getTimeZone("GMT-05:00")

    @Test fun labelKey_fridayDhuhrIsJumuah() {
        assertEquals(AlertPlanner.JUMUAH, AlertPlanner.labelKey("dhuhr", local("2026-11-20T11:41", 3), riyadh))
    }

    @Test fun labelKey_fridayAsrIsUnchanged() {
        assertEquals("asr", AlertPlanner.labelKey("asr", local("2026-11-20T14:39", 3), riyadh))
    }

    @Test fun labelKey_thursdayDhuhrIsUnchanged() {
        assertEquals("dhuhr", AlertPlanner.labelKey("dhuhr", local("2026-11-19T11:41", 3), riyadh))
    }

    @Test fun labelKey_followsTheTriggerDayInTheDeviceZoneNotUtc() {
        val fridayLateNight = local("2026-11-20T23:50", -5)
        assertEquals(AlertPlanner.JUMUAH, AlertPlanner.labelKey("dhuhr", fridayLateNight, newYork))
        assertEquals("dhuhr", AlertPlanner.labelKey("dhuhr", fridayLateNight, utc))
        assertEquals(AlertPlanner.JUMUAH, AlertPlanner.labelKey("dhuhr", local("2026-11-20T02:00", 3), riyadh))
    }

    @Test fun labelKey_fridayTriggerDeliveredAfterMidnightStaysJumuah() {
        val trigger = local("2026-11-20T23:50", 3)
        val deliveredAt = local("2026-11-21T00:20", 3)
        assertEquals(AlertPlanner.JUMUAH, AlertPlanner.labelKey("dhuhr", trigger, riyadh))
        assertEquals("dhuhr", AlertPlanner.labelKey("dhuhr", deliveredAt, riyadh))
    }

    @Test fun keyFor_usesTheLocalDate() {
        assertEquals("2026-11-15/isha", AlertPlanner.keyFor(ms("2026-11-15T18:16"), "isha", utc))
        assertEquals("2026-11-16/isha", AlertPlanner.keyFor(ms("2026-11-15T22:30"), "isha", TimeZone.getTimeZone("GMT+03:00")))
    }

    @Test fun planReminders_subtractsMinutesAndUses300Base() {
        val plan = AlertPlanner.planReminders(tenDays, mapOf("asr" to ReminderSpec(15, "tone")), ms("2026-11-15T13:00"), utc)
        assertEquals(342, plan.first().requestCode)
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

    @Test fun prayerAt_rollsForwardInADstGap() {
        val newYork = TimeZone.getTimeZone("America/New_York")
        assertEquals(ms("2026-03-08T07:30"), AlertPlanner.prayerAt(Day("2026-03-08", mapOf("fajr" to "02:30")), "fajr", newYork))
    }

    @Test fun planSlots_keepsOverdueUnrecordedAlarm() {
        val now = trigger + 10 * minute
        val previous = listOf(Slot(202, "2026-11-15/asr", trigger))
        val result = AlertPlanner.planSlots(200, emptyList(), previous, emptySet(), now)
        assertFalse(result.cancel.contains(202))
        assertEquals(previous, result.slots)
        assertEquals(39, result.cancel.size)
    }

    @Test fun planSlots_cancelsRecordedOrOldOverdueAlarms() {
        val previous = listOf(Slot(202, "2026-11-15/asr", trigger))
        assertTrue(AlertPlanner.planSlots(200, emptyList(), previous, setOf("2026-11-15/asr"), trigger + 10 * minute).cancel.contains(202))
        val old = AlertPlanner.planSlots(200, emptyList(), previous, emptySet(), trigger + 31 * minute)
        assertTrue(old.cancel.contains(202))
        assertTrue(old.slots.isEmpty())
    }

    @Test fun planSlots_afterIshaKeepsTonightsPendingCode() {
        val now = ms("2026-11-15T18:30")
        val plan = AlertPlanner.planAdhans(tenDays, allOn, now, utc)
        val tonight = Slot(244, "2026-11-15/isha", ms("2026-11-15T18:16"))
        assertEquals("2026-11-16/fajr", plan.first().key)
        assertTrue(plan.none { it.requestCode == tonight.requestCode })
        val result = AlertPlanner.planSlots(200, plan, listOf(tonight), emptySet(), now)
        assertFalse(result.cancel.contains(tonight.requestCode))
        assertTrue(result.slots.contains(tonight))
    }

    @Test fun planSlots_afterLateIshaKeepsYesterdaysPendingCode() {
        val lateIsha = (15..24).map { Day("2026-11-$it", day("2026-11-$it").timings + ("isha" to "23:50")) }
        val now = ms("2026-11-16T00:10")
        val plan = AlertPlanner.planAdhans(lateIsha, allOn, now, utc)
        val yesterday = Slot(244, "2026-11-15/isha", ms("2026-11-15T23:50"))
        assertTrue(plan.none { it.requestCode == yesterday.requestCode })
        assertEquals(7, plan.map { it.key.substringBefore('/') }.distinct().size)
        val result = AlertPlanner.planSlots(200, plan, listOf(yesterday), emptySet(), now)
        assertFalse(result.cancel.contains(yesterday.requestCode))
        assertTrue(result.slots.contains(yesterday))
    }

    @Test fun planAdhans_codesAreStableForADateAcrossRearms() {
        val first = AlertPlanner.planAdhans(tenDays, allOn, ms("2026-11-15T13:00"), utc).associate { it.key to it.requestCode }
        val second = AlertPlanner.planAdhans(tenDays, allOn, ms("2026-11-16T13:00"), utc).associate { it.key to it.requestCode }
        val third = AlertPlanner.planAdhans(tenDays, allOn, ms("2026-11-17T20:00"), utc).associate { it.key to it.requestCode }
        assertEquals(first["2026-11-21/isha"], second["2026-11-21/isha"])
        assertEquals(second["2026-11-22/fajr"], third["2026-11-22/fajr"])
        for ((a, b) in listOf(first to second, second to third)) {
            for (k in a.keys intersect b.keys) assertEquals(k, a[k], b[k])
        }
    }

    @Test fun planSlots_rearmEveryTenMinutesNeverSharesACode() {
        val lateIsha = (15..24).map { Day("2026-11-$it", day("2026-11-$it").timings + ("isha" to "23:50")) }
        for (days in listOf(tenDays, lateIsha)) {
            var previous = emptyList<Slot>()
            var now = ms("2026-11-15T00:00")
            while (now < ms("2026-11-18T00:00")) {
                val plan = AlertPlanner.planAdhans(days, allOn, now, utc)
                val result = AlertPlanner.planSlots(200, plan, previous, emptySet(), now)
                val pending = previous.filter { it.triggerAt > now - 30 * minute && it.triggerAt <= now }
                assertTrue(result.slots.containsAll(pending))
                assertEquals(result.slots.size, result.slots.map { it.requestCode }.distinct().size)
                assertEquals(result.slots.size, result.slots.map { it.key }.distinct().size)
                assertTrue(result.cancel.none { c -> result.slots.any { it.requestCode == c } })
                val before = previous.associate { it.key to it.requestCode }
                for (s in result.slots) before[s.key]?.let { assertEquals(s.key, it, s.requestCode) }
                previous = result.slots
                now += 10 * minute
            }
        }
    }

    @Test fun planAdhans_gappedSnapshotStaysInsideTheCodeWindow() {
        val gapped = (15..17).map { day("2026-11-$it") } + (20..30).map { day("2026-11-$it") }
        val plan = AlertPlanner.planAdhans(gapped, allOn, ms("2026-11-15T01:00"), utc)
        assertEquals(listOf("2026-11-15", "2026-11-16", "2026-11-17", "2026-11-20", "2026-11-21", "2026-11-22"), plan.map { it.key.substringBefore('/') }.distinct())
        assertEquals(plan.size, plan.map { it.requestCode }.distinct().size)
        val reminders = AlertPlanner.planReminders(gapped, PRAYERS.associateWith { ReminderSpec(10, "tone") }, ms("2026-11-15T00:00"), utc)
        assertEquals(reminders.size, reminders.map { it.requestCode }.distinct().size)
        assertTrue(reminders.all { it.requestCode in 300..374 })
    }

    @Test fun planSlots_upgradeFromSlotCodesCancelsEveryOldCodeWithoutDuplicates() {
        val now = ms("2026-11-15T14:00")
        val oldNow = ms("2026-11-15T13:00")
        val dates = (15..21).map { "2026-11-$it" }
        val old = dates.flatMapIndexed { slot, date ->
            PRAYERS.mapIndexedNotNull { i, p ->
                val at = AlertPlanner.prayerAt(day(date), p, utc)!!
                if (at <= oldNow) null else Slot(200 + slot * 10 + i, "$date/$p", at)
            }
        }
        val plan = AlertPlanner.planAdhans(tenDays, allOn, now, utc)
        val result = AlertPlanner.planSlots(200, plan, old, emptySet(), now)
        val planned = plan.map { it.requestCode }.toSet()
        assertEquals(plan.map { Slot(it.requestCode, it.key, it.triggerAt) }, result.slots)
        assertTrue(old.all { it.requestCode in planned || it.requestCode in result.cancel })
        assertTrue(result.cancel.none { it in planned })
        assertTrue(result.cancel.containsAll((230..234).toList()))
        val v1 = (0..2).flatMap { d -> (0..4).map { 200 + d * 10 + it } } + (300..304)
        val all = AlertPlanner.staleRequestCodes(200, emptySet()) + AlertPlanner.staleRequestCodes(300, emptySet())
        assertTrue(all.containsAll(v1))
    }

    @Test fun planSlots_overdueSlotForAReplannedKeyIsDropped() {
        val now = trigger + 10 * minute
        val moved = AlertPlanner.PlannedAlarm("2026-11-15/asr", "asr", 242, trigger + 20 * minute, trigger + 20 * minute, next)
        val result = AlertPlanner.planSlots(200, listOf(moved), listOf(Slot(202, "2026-11-15/asr", trigger)), emptySet(), now)
        assertEquals(listOf(Slot(242, "2026-11-15/asr", trigger + 20 * minute)), result.slots)
        assertTrue(result.cancel.contains(202))
    }

    @Test fun requestCodes_neverReachHealOrTestCodes() {
        val all = AlertPlanner.staleRequestCodes(200, emptySet()) + AlertPlanner.staleRequestCodes(300, emptySet())
        assertEquals(80, all.toSet().size)
        assertFalse(all.contains(AlertPlanner.HEAL_REQUEST_CODE))
        assertFalse(all.contains(AlertPlanner.TEST_REQUEST_CODE))
    }

    @Test fun slots_roundTrip() {
        val slots = listOf(Slot(202, "2026-11-15/asr", trigger))
        assertEquals(slots, AlertPlanner.decodeSlots(AlertPlanner.encodeSlots(slots)))
        assertTrue(AlertPlanner.decodeSlots("[oops").isEmpty())
    }

    @Test fun route_exactlyThirtyMinutesDelivers() {
        assertEquals(Route.DELIVER, routeAt(trigger + 30 * minute))
    }

    @Test fun detectMisses_lastCheckedAtBoundsUnrecordedMisses() {
        val armed = mapOf("2026-11-15/asr" to ArmedEntry(trigger, armedAt))
        val now = ms("2026-11-15T17:00")
        assertTrue(AlertPlanner.detectMisses(armed, emptyMap(), trigger, 0, 0, now).isEmpty())
        assertEquals(listOf(Miss("asr", trigger)), AlertPlanner.detectMisses(armed, emptyMap(), trigger - 1, 0, 0, now))
    }

    @Test fun detectMisses_reachesBack24Hours() {
        val armed = mapOf("2026-11-15/asr" to ArmedEntry(trigger, armedAt))
        assertTrue(AlertPlanner.detectMisses(armed, emptyMap(), 0, 0, 0, trigger + 25 * 60 * minute).isEmpty())
        assertEquals(listOf(Miss("asr", trigger)), AlertPlanner.detectMisses(armed, emptyMap(), 0, 0, 0, trigger + 23 * 60 * minute))
    }

    @Test fun detectMisses_waits35Minutes() {
        val armed = mapOf("2026-11-15/asr" to ArmedEntry(trigger, armedAt))
        assertTrue(AlertPlanner.detectMisses(armed, emptyMap(), 0, 0, 0, trigger + 34 * minute).isEmpty())
        assertEquals(listOf(Miss("asr", trigger)), AlertPlanner.detectMisses(armed, emptyMap(), 0, 0, 0, trigger + 36 * minute))
    }

    @Test fun planReminders_legacySnapshotPlansVibrateReminders() {
        val s = AlertPlanner.parseReminderSnapshot("""{"days":[{"date":"2026-11-15","timings":{"asr":"14:39"}}],"reminders":{"asr":10},"locale":"en"}""")
        val plan = AlertPlanner.planReminders(s.days, s.reminders, ms("2026-11-15T13:00"), utc)
        assertEquals(listOf(ms("2026-11-15T14:29")), plan.map { it.triggerAt })
    }

    @Test fun planReminders_skipsZeroMinuteEntries() {
        val plan = AlertPlanner.planReminders(tenDays, mapOf("asr" to ReminderSpec(0, "tone"), "isha" to ReminderSpec(5, "tone")), ms("2026-11-15T13:00"), utc)
        assertTrue(plan.none { it.prayer == "asr" })
        assertEquals(344, plan.first().requestCode)
    }
}

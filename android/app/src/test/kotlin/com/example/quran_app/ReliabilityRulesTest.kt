package com.example.quran_app

import com.example.quran_app.AlertPlanner.AdhanSpec
import com.example.quran_app.AlertPlanner.Miss
import com.example.quran_app.AlertPlanner.OsState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ReliabilityRulesTest {

    private val details = "android.settings.APPLICATION_DETAILS_SETTINGS"

    @Test fun isXiaomiMatchesBrandsCaseInsensitive() {
        assertTrue(AlertPlanner.isXiaomi("Xiaomi", "Redmi"))
        assertTrue(AlertPlanner.isXiaomi("unknown", "POCO"))
        assertFalse(AlertPlanner.isXiaomi("samsung", "samsung"))
        assertFalse(AlertPlanner.isXiaomi(null, null))
    }

    @Test fun autostartCandidatesInSpecOrder() {
        val c = AlertPlanner.settingsCandidates("autostart", "com.example.quran_app", "Al-Furqan", 34)
        assertEquals(3, c.size)
        assertEquals("com.miui.securitycenter", c[0].pkg)
        assertEquals("com.miui.permcenter.autostart.AutoStartManagementActivity", c[0].cls)
        assertEquals("com.miui.securitycenter", c[1].pkg)
        assertEquals("com.miui.permcenter.permissions.PermissionsEditorActivity", c[1].cls)
        assertEquals("com.example.quran_app", c[1].extras["extra_pkgname"])
        assertEquals(details, c.last().action)
        assertEquals("com.example.quran_app", c.last().pkg)
        assertNull(c.last().cls)
    }

    @Test fun xiaomiBatteryFallsBackToBatteryThenDetails() {
        val c = AlertPlanner.settingsCandidates("xiaomiBattery", "com.example.quran_app", "Al-Furqan", 34)
        assertEquals("com.miui.powerkeeper", c[0].pkg)
        assertEquals("com.miui.powerkeeper.ui.HiddenAppsConfigActivity", c[0].cls)
        assertEquals(mapOf("package_name" to "com.example.quran_app", "package_label" to "Al-Furqan"), c[0].extras)
        assertEquals("android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS", c[1].action)
        assertEquals(details, c[2].action)
        assertEquals(3, c.size)
    }

    @Test fun batteryHasNoPackageDataThenDetails() {
        val c = AlertPlanner.settingsCandidates("battery", "p", "l", 34)
        assertEquals(2, c.size)
        assertEquals("android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS", c[0].action)
        assertNull(c[0].pkg)
        assertEquals(details, c[1].action)
    }

    @Test fun notificationsAndExactAlarmTargets() {
        val notifications = AlertPlanner.settingsCandidates("notifications", "p", "l", 34)
        assertEquals("android.settings.APP_NOTIFICATION_SETTINGS", notifications[0].action)
        assertNull(notifications[0].pkg)
        assertEquals(mapOf("android.provider.extra.APP_PACKAGE" to "p"), notifications[0].extras)
        assertEquals(details, notifications.last().action)
        val exact = AlertPlanner.settingsCandidates("exactAlarm", "p", "l", 34)
        assertEquals("android.settings.REQUEST_SCHEDULE_EXACT_ALARM", exact[0].action)
        assertEquals("p", exact[0].pkg)
        assertEquals(details, exact.last().action)
        val bogus = AlertPlanner.settingsCandidates("bogus", "p", "l", 34)
        assertEquals(1, bogus.size)
        assertEquals(details, bogus.single().action)
    }

    @Test fun notificationsBelowApi26GoStraightToDetails() {
        val c = AlertPlanner.settingsCandidates("notifications", "p", "l", 25)
        assertEquals(1, c.size)
        assertEquals(details, c.single().action)
        assertEquals("p", c.single().pkg)
        assertEquals("android.settings.APP_NOTIFICATION_SETTINGS", AlertPlanner.settingsCandidates("notifications", "p", "l", 26)[0].action)
    }

    @Test fun ackCheckpointNeverMovesBack() {
        assertEquals(500L, AlertPlanner.ackCheckpoint(null, 500L))
        assertEquals(900L, AlertPlanner.ackCheckpoint(900L, 500L))
        assertEquals(1_200L, AlertPlanner.ackCheckpoint(900L, 1_200L))
    }

    @Test fun statusChannelsUnionRoutesWithPlayback() {
        val alerts = mapOf("fajr" to AdhanSpec("vibrate", false), "isha" to AdhanSpec("silent", false))
        assertEquals(
            setOf("prayer_alert_vibrate_v2", "prayer_alert_silent_v2", "prayer_adhan_channel"),
            AlertPlanner.statusChannels(alerts),
        )
        assertEquals(setOf("prayer_adhan_channel", "prayer_alert_tone_v2"), AlertPlanner.statusChannels(mapOf("asr" to AdhanSpec("adhan", true))))
        assertEquals(setOf("prayer_adhan_channel"), AlertPlanner.statusChannels(emptyMap()))
    }

    @Test fun exactAlarmsAllowedByApiLevel() {
        assertFalse(AlertPlanner.exactAlarmsAllowed(33) { false })
        assertTrue(AlertPlanner.exactAlarmsAllowed(34) { true })
        assertFalse(AlertPlanner.exactAlarmsAllowed(31) { false })
        assertTrue(AlertPlanner.exactAlarmsAllowed(32) { true })
        assertTrue(AlertPlanner.exactAlarmsAllowed(30) { throw AssertionError("not called below 31") })
    }

    @Test fun exactGrantRearmsOnlyWhenStillAllowed() {
        val granted = "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED"
        assertTrue(AlertPlanner.rearmOnExactGrant(granted, 34) { true })
        assertFalse(AlertPlanner.rearmOnExactGrant(granted, 34) { false })
        assertTrue(AlertPlanner.rearmOnExactGrant(granted, 30) { throw AssertionError("not called below 31") })
        assertFalse(AlertPlanner.rearmOnExactGrant("android.intent.action.BOOT_COMPLETED", 34) { throw AssertionError("not called") })
        assertFalse(AlertPlanner.rearmOnExactGrant(null, 34) { true })
    }

    @Test fun statusMapCarriesExactlyTheDartKeys() {
        val map = AlertPlanner.statusMap(
            OsState(notificationsEnabled = true, channelBlocked = false, exactAlarmsAllowed = true, batteryUnrestricted = false, isXiaomi = true),
            usesAlarmClock = true,
            scheduledUntil = 1_763_000_000_000L,
            snapshotUntil = "2026-12-31",
            missed = listOf(Miss("isha", 1_762_900_000_000L)),
            late = emptyList(),
        )
        assertEquals(
            setOf(
                "notificationsEnabled", "channelBlocked", "exactAlarmsAllowed", "batteryUnrestricted", "isXiaomi",
                "usesAlarmClock", "scheduledUntil", "snapshotUntil", "missed", "late",
            ),
            map.keys,
        )
        assertEquals(true, map["notificationsEnabled"])
        assertEquals(false, map["batteryUnrestricted"])
        assertEquals(true, map["isXiaomi"])
        assertEquals(true, map["usesAlarmClock"])
        assertEquals(1_763_000_000_000L, map["scheduledUntil"])
        assertEquals("2026-12-31", map["snapshotUntil"])
        assertEquals(listOf(mapOf("prayer" to "isha", "at" to 1_762_900_000_000L)), map["missed"])
        assertEquals(emptyList<Any>(), map["late"])
        assertTrue(map["missed"] is List<*>)
    }

    @Test fun statusMapKeepsNullHorizons() {
        val map = AlertPlanner.statusMap(
            OsState(true, false, true, true, false), usesAlarmClock = false,
            scheduledUntil = null, snapshotUntil = null, missed = emptyList(), late = emptyList(),
        )
        assertTrue(map.containsKey("scheduledUntil"))
        assertNull(map["scheduledUntil"])
        assertNull(map["snapshotUntil"])
        assertEquals(false, map["usesAlarmClock"])
    }
}

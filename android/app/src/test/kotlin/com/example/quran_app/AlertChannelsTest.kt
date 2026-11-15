package com.example.quran_app

import android.media.AudioAttributes
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AlertChannelsTest {

    @Test fun deliveryChannelFollowsSound() {
        assertEquals("prayer_adhan_channel", AlertPlanner.deliveryChannel("adhan", playing = true))
        assertEquals("prayer_alert_tone_v2", AlertPlanner.deliveryChannel("adhan", playing = false))
        assertEquals("prayer_alert_tone_v2", AlertPlanner.deliveryChannel("tone", playing = false))
        assertEquals("prayer_alert_vibrate_v2", AlertPlanner.deliveryChannel("vibrate", playing = false))
        assertEquals("prayer_alert_silent_v2", AlertPlanner.deliveryChannel("silent", playing = false))
    }

    @Test fun routeChannelsForAdhanIncludePlaybackAndTone() {
        assertEquals(setOf("prayer_adhan_channel", "prayer_alert_tone_v2"), AlertPlanner.routeChannels("adhan"))
        assertEquals(setOf("prayer_alert_silent_v2"), AlertPlanner.routeChannels("silent"))
    }

    @Test fun reminderChannelFollowsReminderSound() {
        assertEquals("prayer_reminder_tone_v2", AlertPlanner.reminderChannel("tone"))
        assertEquals("prayer_reminder_channel", AlertPlanner.reminderChannel("vibrate"))
        assertEquals("prayer_reminder_silent_v2", AlertPlanner.reminderChannel("silent"))
    }

    @Test fun clipForFajrOnly() {
        assertEquals("fajr_adhan", AlertPlanner.clipFor("fajr"))
        assertEquals("normal_adhan", AlertPlanner.clipFor("isha"))
    }

    @Test fun playsOnlyAdhanWhenAudibleOrRingInSilent() {
        assertTrue(AlertPlanner.plays("adhan", ringInSilent = true, audible = false))
        assertTrue(AlertPlanner.plays("adhan", ringInSilent = false, audible = true))
        assertFalse(AlertPlanner.plays("adhan", ringInSilent = false, audible = false))
        assertFalse(AlertPlanner.plays("tone", ringInSilent = true, audible = true))
        assertFalse(AlertPlanner.plays("vibrate", ringInSilent = true, audible = true))
    }

    @Test fun playbackUsesAlarmStreamOnlyWhenRingInSilent() {
        assertEquals(AudioAttributes.USAGE_ALARM, playbackUsage(ringInSilent = true))
        assertEquals(AudioAttributes.USAGE_NOTIFICATION_EVENT, playbackUsage(ringInSilent = false))
    }

    @Test fun channelIdsMatchTheirOwners() {
        assertEquals(AdhanPlaybackService.CHANNEL_ID, AlertPlanner.deliveryChannel("adhan", playing = true))
        assertEquals(PrayerReminderReceiver.CHANNEL_ID, AlertPlanner.reminderChannel("vibrate"))
    }
}

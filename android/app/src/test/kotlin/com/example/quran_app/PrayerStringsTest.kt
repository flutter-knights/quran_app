package com.example.quran_app

import org.junit.Assert.assertEquals
import org.junit.Test

class PrayerStringsTest {

    private val labels = AlertPlanner.PRAYERS + AlertPlanner.JUMUAH

    @Test fun adhanTextMapsEveryLabelToItsOwnStrings() {
        assertEquals(
            listOf(
                R.string.adhan_title_fajr, R.string.adhan_title_dhuhr, R.string.adhan_title_asr,
                R.string.adhan_title_maghrib, R.string.adhan_title_isha, R.string.adhan_title_jumuah,
            ),
            labels.map(PrayerStrings::adhanTitle),
        )
        assertEquals(
            listOf(
                R.string.adhan_body_fajr, R.string.adhan_body_dhuhr, R.string.adhan_body_asr,
                R.string.adhan_body_maghrib, R.string.adhan_body_isha, R.string.adhan_body_jumuah,
            ),
            labels.map(PrayerStrings::adhanBody),
        )
    }

    @Test fun reminderTextMapsEveryLabelToItsOwnStrings() {
        assertEquals(
            listOf(
                R.string.reminder_title_fajr, R.string.reminder_title_dhuhr, R.string.reminder_title_asr,
                R.string.reminder_title_maghrib, R.string.reminder_title_isha, R.string.reminder_title_jumuah,
            ),
            labels.map(PrayerStrings::reminderTitle),
        )
        assertEquals(
            listOf(
                R.string.reminder_body_fajr, R.string.reminder_body_dhuhr, R.string.reminder_body_asr,
                R.string.reminder_body_maghrib, R.string.reminder_body_isha, R.string.reminder_body_jumuah,
            ),
            labels.map(PrayerStrings::reminderBody),
        )
    }

    @Test fun unknownLabelFallsBackToFajr() {
        assertEquals(R.string.adhan_title_fajr, PrayerStrings.adhanTitle("sunrise"))
        assertEquals(R.string.adhan_body_fajr, PrayerStrings.adhanBody("sunrise"))
        assertEquals(R.string.reminder_title_fajr, PrayerStrings.reminderTitle("sunrise"))
        assertEquals(R.string.reminder_body_fajr, PrayerStrings.reminderBody("sunrise"))
    }
}

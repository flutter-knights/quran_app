package com.example.quran_app

/**
 * Single source of truth for the prayer → reminder-notification-ID mapping.
 *
 * Deliberately NOT keyed on PrayerName.values — the enum also contains
 * `sunrise`, which has no reminder, and using `.index` would shift IDs.
 */
object PrayerReminderIds {

    const val NOTIFICATION_ID_BASE = 2300

    /** Lowercase prayer name -> notification ID. */
    val notificationIdByPrayer: Map<String, Int> = linkedMapOf(
        "fajr"    to 2300,
        "dhuhr"   to 2301,
        "asr"     to 2302,
        "maghrib" to 2303,
        "isha"    to 2304,
    )

    val allPrayers: List<String> = notificationIdByPrayer.keys.toList()
}

package com.example.quran_app

/**
 * Single source of truth for the prayer → reminder-notification-ID mapping.
 *
 * Deliberately NOT keyed on PrayerName.values — the enum also contains
 * `sunrise`, which has no reminder, and using `.index` would shift IDs.
 */
object PrayerReminderIds {

    const val NOTIFICATION_ID_BASE = 2300
    const val REQUEST_CODE_BASE = 300

    /** Lowercase prayer name -> notification ID. Order matches request codes. */
    val notificationIdByPrayer: Map<String, Int> = linkedMapOf(
        "fajr"    to 2300,
        "dhuhr"   to 2301,
        "asr"     to 2302,
        "maghrib" to 2303,
        "isha"    to 2304,
    )

    /** Lowercase prayer name -> PendingIntent request code. */
    val requestCodeByPrayer: Map<String, Int> = linkedMapOf(
        "fajr"    to 300,
        "dhuhr"   to 301,
        "asr"     to 302,
        "maghrib" to 303,
        "isha"    to 304,
    )

    val allPrayers: List<String> = notificationIdByPrayer.keys.toList()
}

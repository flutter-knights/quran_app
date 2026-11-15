package com.example.quran_app

import android.content.Context
import android.content.res.Configuration
import java.util.Locale

fun localizedContext(context: Context, localeCode: String): Context {
    val config = Configuration(context.resources.configuration)
    config.setLocale(Locale.forLanguageTag(localeCode))
    return context.createConfigurationContext(config)
}

fun adhanText(localized: Context, label: String): Pair<String, String> =
    localized.getString(PrayerStrings.adhanTitle(label)) to localized.getString(PrayerStrings.adhanBody(label))

object PrayerStrings {
    fun adhanTitle(label: String): Int = when (label) {
        "dhuhr" -> R.string.adhan_title_dhuhr
        "asr" -> R.string.adhan_title_asr
        "maghrib" -> R.string.adhan_title_maghrib
        "isha" -> R.string.adhan_title_isha
        AlertPlanner.JUMUAH -> R.string.adhan_title_jumuah
        else -> R.string.adhan_title_fajr
    }

    fun adhanBody(label: String): Int = when (label) {
        "dhuhr" -> R.string.adhan_body_dhuhr
        "asr" -> R.string.adhan_body_asr
        "maghrib" -> R.string.adhan_body_maghrib
        "isha" -> R.string.adhan_body_isha
        AlertPlanner.JUMUAH -> R.string.adhan_body_jumuah
        else -> R.string.adhan_body_fajr
    }

    fun reminderTitle(label: String): Int = when (label) {
        "dhuhr" -> R.string.reminder_title_dhuhr
        "asr" -> R.string.reminder_title_asr
        "maghrib" -> R.string.reminder_title_maghrib
        "isha" -> R.string.reminder_title_isha
        AlertPlanner.JUMUAH -> R.string.reminder_title_jumuah
        else -> R.string.reminder_title_fajr
    }

    fun reminderBody(label: String): Int = when (label) {
        "dhuhr" -> R.string.reminder_body_dhuhr
        "asr" -> R.string.reminder_body_asr
        "maghrib" -> R.string.reminder_body_maghrib
        "isha" -> R.string.reminder_body_isha
        AlertPlanner.JUMUAH -> R.string.reminder_body_jumuah
        else -> R.string.reminder_body_fajr
    }
}

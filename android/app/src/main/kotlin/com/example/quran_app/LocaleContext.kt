package com.example.quran_app

import android.content.Context
import android.content.res.Configuration
import java.util.Locale

fun localizedContext(context: Context, localeCode: String): Context {
    val config = Configuration(context.resources.configuration)
    config.setLocale(Locale.forLanguageTag(localeCode))
    return context.createConfigurationContext(config)
}

fun adhanText(localized: Context, prayer: String): Pair<String, String> {
    val res = localized.resources
    val title = res.getIdentifier("adhan_title_$prayer", "string", localized.packageName)
        .let { if (it != 0) it else R.string.adhan_title_fajr }
    val body = res.getIdentifier("adhan_body_$prayer", "string", localized.packageName)
        .let { if (it != 0) it else R.string.adhan_body_fajr }
    return localized.getString(title) to localized.getString(body)
}

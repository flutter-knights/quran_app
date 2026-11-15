package com.example.quran_app

import android.content.Context
import android.content.res.Configuration
import java.util.Locale

fun localizedContext(context: Context, localeCode: String): Context {
    val config = Configuration(context.resources.configuration)
    config.setLocale(Locale.forLanguageTag(localeCode))
    return context.createConfigurationContext(config)
}

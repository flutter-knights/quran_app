package com.example.quran_app

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Handles the `quran_app/notifications` MethodChannel.
 *
 * Strip routes: enableStrip / refreshStrip / disableStrip → PrayerStripController.
 * Adhan routes: scheduleDailyAdhans / cancelAllAdhans / scheduleTestAdhan → AdhanScheduler.
 */
class PrayerStripPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null
    private var appContext: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        appContext = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = appContext ?: run {
            result.error("NO_CONTEXT", "Plugin not attached", null)
            return
        }
        when (call.method) {
            "enableStrip", "refreshStrip" -> handleEnableOrRefreshStrip(ctx, call, result)
            "disableStrip" -> handleDisableStrip(ctx, result)
            "scheduleDailyAdhans" -> handleScheduleDailyAdhans(ctx, call, result)
            "cancelAllAdhans" -> handleCancelAllAdhans(ctx, result)
            "scheduleTestAdhan" -> handleScheduleTestAdhan(ctx, call, result)
            "schedulePrayerReminders" -> handleSchedulePrayerReminders(ctx, call, result)
            "cancelAllReminders" -> handleCancelAllReminders(ctx, result)
            else -> result.notImplemented()
        }
    }

    private fun handleEnableOrRefreshStrip(
        ctx: Context, call: MethodCall, result: MethodChannel.Result
    ) {
        val json = serializeStripArgs(call.arguments)
        if (json == null) {
            result.error("BAD_ARGS", "Expected {days:[...]} state, got ${call.arguments}", null)
            return
        }
        PrayerStripController.show(ctx, json)
        result.success(null)
    }

    private fun handleDisableStrip(ctx: Context, result: MethodChannel.Result) {
        PrayerStripController.hide(ctx)
        result.success(null)
    }

    private fun handleScheduleDailyAdhans(
        ctx: Context, call: MethodCall, result: MethodChannel.Result
    ) {
        val args = call.arguments as? Map<*, *>
        if (args == null) {
            result.error("BAD_ARGS", "Expected Map", null)
            return
        }
        @Suppress("UNCHECKED_CAST")
        val timings = (args["timings"] as? Map<String, String>) ?: emptyMap()
        @Suppress("UNCHECKED_CAST")
        val clips = (args["clips"] as? Map<String, String>) ?: emptyMap()
        val localeCode = (args["localeCode"] as? String) ?: "en"

        AdhanScheduler.armToday(ctx, timings, clips, localeCode)
        result.success(null)
    }

    private fun handleCancelAllAdhans(ctx: Context, result: MethodChannel.Result) {
        AdhanScheduler.cancelAll(ctx)
        result.success(null)
    }

    private fun handleScheduleTestAdhan(
        ctx: Context, call: MethodCall, result: MethodChannel.Result
    ) {
        val args = call.arguments as? Map<*, *>
        val delay = (args?.get("delaySeconds") as? Int) ?: 30
        val localeCode = (args?.get("localeCode") as? String) ?: "en"
        AdhanScheduler.armTest(ctx, delay, localeCode)
        result.success(null)
    }

    private fun handleSchedulePrayerReminders(
        ctx: Context, call: MethodCall, result: MethodChannel.Result
    ) {
        val args = call.arguments as? Map<*, *>
        if (args == null) {
            result.error("BAD_ARGS", "Expected Map", null)
            return
        }
        @Suppress("UNCHECKED_CAST")
        val remindersByPrayer = (args["remindersByPrayer"] as? Map<String, Int>)
            ?: emptyMap()
        @Suppress("UNCHECKED_CAST")
        val timings = (args["timings"] as? Map<String, String>) ?: emptyMap()
        val localeCode = (args["localeCode"] as? String) ?: "en"

        PrayerReminderScheduler.armToday(
            ctx, remindersByPrayer, timings, localeCode,
        )
        result.success(null)
    }

    private fun handleCancelAllReminders(
        ctx: Context, result: MethodChannel.Result,
    ) {
        PrayerReminderScheduler.cancelAll(ctx)
        result.success(null)
    }

    private fun serializeStripArgs(args: Any?): String? {
        if (args !is Map<*, *>) return null
        val daysRaw = args["days"] as? List<*> ?: return null
        val daysArr = org.json.JSONArray()
        for (d in daysRaw) {
            val dm = d as? Map<*, *> ?: return null
            val cellsRaw = dm["cells"] as? List<*> ?: return null
            val cellsArr = org.json.JSONArray()
            for (c in cellsRaw) {
                val cm = c as? Map<*, *> ?: return null
                cellsArr.put(
                    org.json.JSONObject()
                        .put("label", cm["label"] as? String ?: return null)
                        .put("time", cm["time"] as? String ?: return null)
                        .put("minutes", (cm["minutes"] as? Int) ?: return null)
                )
            }
            val dObj = org.json.JSONObject()
                .put("dateKey", dm["dateKey"] as? String ?: return null)
                .put("cells", cellsArr)
                .put("hijriDateLabel", dm["hijriDateLabel"] as? String ?: return null)
                .put("weekdayLabel", dm["weekdayLabel"] as? String ?: return null)
                .put("localeCode", dm["localeCode"] as? String ?: return null)
                .put("isFriday", dm["isFriday"] as? Boolean ?: return null)
            (dm["accentColor"] as? String)?.let { dObj.put("accentColor", it) }
            daysArr.put(dObj)
        }
        return org.json.JSONObject().put("days", daysArr).toString()
    }

    companion object {
        const val CHANNEL = "quran_app/notifications"
    }
}

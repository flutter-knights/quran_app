package com.example.quran_app

import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Handles the `quran_app/notifications` MethodChannel.
 *
 * Strip routes (unchanged): enableStrip / refreshStrip / disableStrip → PrayerStripService.
 * Adhan routes (NEW):       scheduleDailyAdhans / cancelAllAdhans / scheduleTestAdhan → AdhanScheduler.
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
            result.error("BAD_ARGS", "Expected Map state, got ${call.arguments}", null)
            return
        }
        val intent = Intent(ctx, PrayerStripService::class.java).apply {
            action = PrayerStripService.ACTION_SHOW_STRIP
            putExtra(PrayerStripService.EXTRA_STATE_JSON, json)
        }
        ctx.startForegroundService(intent)
        result.success(null)
    }

    private fun handleDisableStrip(ctx: Context, result: MethodChannel.Result) {
        val intent = Intent(ctx, PrayerStripService::class.java).apply {
            action = PrayerStripService.ACTION_HIDE_STRIP
        }
        ctx.startForegroundService(intent)
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

        // Parse multi-day payload: args["days"] is a List of {date:String, timings:Map}
        val daysRaw = args["days"] as? List<*> ?: emptyList<Any?>()
        val days = daysRaw.mapNotNull { e ->
            val m = e as? Map<*, *> ?: return@mapNotNull null
            val date = m["date"] as? String ?: return@mapNotNull null
            val timingsRaw = m["timings"] as? Map<*, *>
            val timings = timingsRaw.orEmpty()
                .entries
                .mapNotNull { (k, v) ->
                    val ks = k as? String ?: return@mapNotNull null
                    val vs = v as? String ?: return@mapNotNull null
                    ks to vs
                }
                .toMap()
            AdhanScheduler.DaySchedule(date, timings)
        }

        @Suppress("UNCHECKED_CAST")
        val clips = (args["clips"] as? Map<String, String>) ?: emptyMap()
        val localeCode = (args["localeCode"] as? String) ?: "en"

        if (days.isEmpty()) {
            Log.w(TAG, "handleScheduleDailyAdhans: no valid days in payload")
        }
        AdhanScheduler.armDays(ctx, days, clips, localeCode)
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

        // Parse multi-day payload: args["days"] is a List of {date:String, timings:Map}
        val daysRaw = args["days"] as? List<*> ?: emptyList<Any?>()
        val days = daysRaw.mapNotNull { e ->
            val m = e as? Map<*, *> ?: return@mapNotNull null
            val date = m["date"] as? String ?: return@mapNotNull null
            val timingsRaw = m["timings"] as? Map<*, *>
            val timings = timingsRaw.orEmpty()
                .entries
                .mapNotNull { (k, v) ->
                    val ks = k as? String ?: return@mapNotNull null
                    val vs = v as? String ?: return@mapNotNull null
                    ks to vs
                }
                .toMap()
            AdhanScheduler.DaySchedule(date, timings)
        }

        @Suppress("UNCHECKED_CAST")
        val remindersByPrayer = (args["remindersByPrayer"] as? Map<String, Int>)
            ?: emptyMap()
        val localeCode = (args["localeCode"] as? String) ?: "en"

        if (days.isEmpty()) {
            Log.w(TAG, "handleSchedulePrayerReminders: no valid days in payload")
        }
        PrayerReminderScheduler.armDays(ctx, days, remindersByPrayer, localeCode)
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
        val obj = org.json.JSONObject()
        val cellsRaw = args["cells"] as? List<*> ?: return null
        val arr = org.json.JSONArray()
        for (c in cellsRaw) {
            val cm = c as? Map<*, *> ?: return null
            arr.put(
                org.json.JSONObject()
                    .put("label", cm["label"] as? String ?: return null)
                    .put("time", cm["time"] as? String ?: return null)
            )
        }
        obj.put("cells", arr)
        obj.put("nextPrayerIndex", (args["nextPrayerIndex"] as? Int) ?: return null)
        obj.put("hijriDateLabel", (args["hijriDateLabel"] as? String) ?: return null)
        obj.put("weekdayLabel", (args["weekdayLabel"] as? String) ?: return null)
        obj.put("localeCode", (args["localeCode"] as? String) ?: return null)
        obj.put("isFriday", (args["isFriday"] as? Boolean) ?: return null)
        // Optional: a `#AARRGGBB` accent for the next-prayer pill. Older callers
        // may omit it, in which case the renderer uses its resource fallback.
        (args["accentColor"] as? String)?.let { obj.put("accentColor", it) }
        return obj.toString()
    }

    companion object {
        const val CHANNEL = "quran_app/notifications"
        private const val TAG = "PrayerStripPlugin"
    }
}

package com.example.quran_app

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
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
        SoundPreviewPlayer.stop()
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
            "getReliabilityStatus" -> replyFromStore(ctx, result) { ReliabilityReader.read(it) }
            "ackMissed" -> handleAckMissed(ctx, call, result)
            "openSystemSettings" -> handleOpenSystemSettings(ctx, call, result)
            "previewSound" -> handlePreviewSound(ctx, call, result)
            "stopPreview" -> {
                SoundPreviewPlayer.stop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleEnableOrRefreshStrip(
        ctx: Context, call: MethodCall, result: MethodChannel.Result
    ) {
        val json = PrayerStripWindow.channelArgsToJson(call.arguments)
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
        val alerts = (args["alerts"] as? Map<*, *>).orEmpty().entries.mapNotNull { (k, v) ->
            val prayer = k as? String ?: return@mapNotNull null
            val m = v as? Map<*, *> ?: return@mapNotNull null
            prayer to AlertPlanner.AdhanSpec(m["sound"] as? String ?: "adhan", m["ringInSilent"] as? Boolean ?: false)
        }.toMap()
        val snapshot = AlertPlanner.AdhanSnapshot(parseDays(args), alerts, localeOf(args), legacy = false)
        runInStore(ctx, result) { AdhanScheduler.sync(it, snapshot) }
    }

    private fun handleCancelAllAdhans(ctx: Context, result: MethodChannel.Result) {
        runInStore(ctx, result) { AdhanScheduler.cancelAll(it) }
    }

    private fun handleScheduleTestAdhan(
        ctx: Context, call: MethodCall, result: MethodChannel.Result
    ) {
        val args = call.arguments as? Map<*, *>
        val delay = (args?.get("delaySeconds") as? Number)?.toInt() ?: 30
        val localeCode = (args?.get("localeCode") as? String) ?: "en"
        val sound = (args?.get("sound") as? String) ?: "adhan"
        val ringInSilent = (args?.get("ringInSilent") as? Boolean) ?: false
        runInStore(ctx, result) { AdhanScheduler.armTest(it, delay, localeCode, sound, ringInSilent) }
    }

    private fun handleSchedulePrayerReminders(
        ctx: Context, call: MethodCall, result: MethodChannel.Result
    ) {
        val args = call.arguments as? Map<*, *>
        if (args == null) {
            result.error("BAD_ARGS", "Expected Map", null)
            return
        }
        val reminders = (args["reminders"] as? Map<*, *>).orEmpty().entries.mapNotNull { (k, v) ->
            val prayer = k as? String ?: return@mapNotNull null
            val m = v as? Map<*, *> ?: return@mapNotNull null
            val minutes = (m["minutes"] as? Number)?.toInt() ?: return@mapNotNull null
            prayer to AlertPlanner.ReminderSpec(minutes, m["reminderSound"] as? String ?: "vibrate")
        }.toMap()
        val snapshot = AlertPlanner.ReminderSnapshot(parseDays(args), reminders, localeOf(args), legacy = false)
        runInStore(ctx, result) { PrayerReminderScheduler.sync(it, snapshot) }
    }

    private fun handleCancelAllReminders(
        ctx: Context, result: MethodChannel.Result,
    ) {
        runInStore(ctx, result) { PrayerReminderScheduler.cancelAll(it) }
    }

    private fun handleOpenSystemSettings(ctx: Context, call: MethodCall, result: MethodChannel.Result) {
        val target = (call.arguments as? Map<*, *>)?.get("target") as? String
        if (target == null) {
            result.error("BAD_ARGS", "Expected {target}", null)
            return
        }
        result.success(SystemSettingsLauncher.open(ctx, target))
    }

    private fun handleAckMissed(ctx: Context, call: MethodCall, result: MethodChannel.Result) {
        val upTo = ((call.arguments as? Map<*, *>)?.get("upTo") as? Number)?.toLong()
        if (upTo == null) {
            result.error("BAD_ARGS", "Expected {upTo}", null)
            return
        }
        runInStore(ctx, result) { ReliabilityReader.ack(it, upTo) }
    }

    private fun handlePreviewSound(ctx: Context, call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val sound = args?.get("sound") as? String
        val prayer = args?.get("prayer") as? String
        if (sound == null || prayer == null) {
            result.error("BAD_ARGS", "Expected {sound, prayer}", null)
            return
        }
        SoundPreviewPlayer.play(ctx, sound, prayer) { ended ->
            channel?.invokeMethod("previewEnded", mapOf("sound" to ended))
        }
        result.success(null)
    }

    private fun parseDays(args: Map<*, *>): List<AlertPlanner.Day> {
        val days = (args["days"] as? List<*>).orEmpty().mapNotNull { e ->
            val m = e as? Map<*, *> ?: return@mapNotNull null
            val date = m["date"] as? String ?: return@mapNotNull null
            val timings = (m["timings"] as? Map<*, *>).orEmpty().entries.mapNotNull { (k, v) ->
                val ks = k as? String ?: return@mapNotNull null
                val vs = v as? String ?: return@mapNotNull null
                ks to vs
            }.toMap()
            AlertPlanner.Day(date, timings)
        }
        if (days.isEmpty()) Log.w(TAG, "parseDays: no valid days in payload")
        return days
    }

    private fun localeOf(args: Map<*, *>) = (args["localeCode"] as? String) ?: "en"

    private fun runInStore(ctx: Context, result: MethodChannel.Result, block: (Context) -> Unit) {
        replyFromStore(ctx, result) {
            block(it)
            null
        }
    }

    private fun replyFromStore(ctx: Context, result: MethodChannel.Result, block: (Context) -> Any?) {
        val main = Handler(Looper.getMainLooper())
        AlertStore.post(ctx) {
            val outcome = try {
                Result.success(block(it))
            } catch (e: Throwable) {
                Log.e(TAG, "replyFromStore: failed", e)
                Result.failure(e)
            }
            main.post {
                outcome.fold(
                    { value -> result.success(value) },
                    { e -> result.error("NATIVE_ERROR", e.message, null) },
                )
            }
        }
    }

    companion object {
        const val CHANNEL = "quran_app/notifications"
        private const val TAG = "PrayerStripPlugin"
    }
}

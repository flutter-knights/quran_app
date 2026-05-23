package com.example.quran_app

import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Handles the `quran_app/notifications` MethodChannel for the strip.
 * Adhan methods (`scheduleDailyAdhans`, `cancelAllAdhans`) are intentionally
 * left unimplemented — Plan A routes them through the legacy scheduler,
 * not this channel.
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
            "enableStrip", "refreshStrip" -> {
                val json = serializeArgs(call.arguments)
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
            "disableStrip" -> {
                val intent = Intent(ctx, PrayerStripService::class.java).apply {
                    action = PrayerStripService.ACTION_HIDE_STRIP
                }
                ctx.startForegroundService(intent)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** Re-serializes a Map<String,Object?> (as Flutter sends it) back to a JSON string
     *  using PrayerStripState's structure. */
    private fun serializeArgs(args: Any?): String? {
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
        obj.put("localeCode", (args["localeCode"] as? String) ?: return null)
        obj.put("isFriday", (args["isFriday"] as? Boolean) ?: return null)
        return obj.toString()
    }

    companion object {
        const val CHANNEL = "quran_app/notifications"
    }
}

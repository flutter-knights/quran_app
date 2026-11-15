package com.example.quran_app

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log

object SystemSettingsLauncher {

    private const val TAG = "SystemSettings"

    fun open(context: Context, target: String) {
        val label = runCatching { context.applicationInfo.loadLabel(context.packageManager).toString() }.getOrDefault(context.packageName)
        for (spec in AlertPlanner.settingsCandidates(target, context.packageName, label)) {
            try {
                context.startActivity(intentFor(spec))
                return
            } catch (e: ActivityNotFoundException) {
                Log.w(TAG, "open: $target unavailable via ${spec.cls ?: spec.action}")
            } catch (e: SecurityException) {
                Log.w(TAG, "open: $target denied via ${spec.cls ?: spec.action}")
            }
        }
        Log.e(TAG, "open: no settings screen for $target")
    }

    private fun intentFor(spec: AlertPlanner.IntentSpec) = Intent().apply {
        if (spec.cls != null && spec.pkg != null) {
            setClassName(spec.pkg, spec.cls)
        } else {
            action = spec.action
            spec.pkg?.let { data = Uri.parse("package:$it") }
        }
        for ((k, v) in spec.extras) putExtra(k, v)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
}

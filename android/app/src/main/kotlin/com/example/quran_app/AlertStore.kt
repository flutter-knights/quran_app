package com.example.quran_app

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import java.util.concurrent.Executors

object AlertStore {

    private const val TAG = "AlertStore"
    private const val PREFS = "alert_store"
    private const val KEY_ARMED = "armed_log"
    private const val KEY_RECORDS = "records"
    const val LAST_CHECKED_AT = "last_checked_at"
    const val LAST_BOOT_HANDLED_AT = "last_boot_handled_at"
    const val LAST_CLOCK_CHANGE_AT = "last_clock_change_at"
    const val SCHEDULED_UNTIL = "scheduled_until"

    const val ADHAN_PREFS = "adhan_prefs"
    const val ADHAN_SNAPSHOT = "adhan_snapshot"
    const val REMINDER_PREFS = "reminder_prefs"
    const val REMINDER_SNAPSHOT = "reminder_snapshot"

    val executor = Executors.newSingleThreadExecutor()

    fun post(context: Context, block: (Context) -> Unit) {
        val app = context.applicationContext
        executor.execute {
            try {
                block(app)
            } catch (e: Exception) {
                Log.e(TAG, "post: task failed", e)
            }
        }
    }

    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun readArmed(context: Context) = AlertPlanner.decodeArmed(prefs(context).getString(KEY_ARMED, null))

    fun writeArmed(context: Context, armed: Map<String, AlertPlanner.ArmedEntry>) {
        prefs(context).edit().putString(KEY_ARMED, AlertPlanner.encodeArmed(armed)).commit()
    }

    fun readRecords(context: Context) = AlertPlanner.decodeRecords(prefs(context).getString(KEY_RECORDS, null))

    fun writeRecord(context: Context, key: String, record: AlertPlanner.Record) {
        val records = AlertPlanner.pruneRecords(readRecords(context) + (key to record), System.currentTimeMillis())
        prefs(context).edit().putString(KEY_RECORDS, AlertPlanner.encodeRecords(records)).commit()
    }

    fun getLong(context: Context, name: String): Long? =
        prefs(context).let { if (it.contains(name)) it.getLong(name, 0L) else null }

    fun setLong(context: Context, name: String, value: Long) {
        prefs(context).edit().putLong(name, value).commit()
    }

    fun setIfUnset(context: Context, name: String, value: Long) {
        if (!prefs(context).contains(name)) setLong(context, name, value)
    }

    fun remove(context: Context, name: String) {
        prefs(context).edit().remove(name).commit()
    }

    fun readSnapshot(context: Context, prefsName: String, key: String): String? =
        context.getSharedPreferences(prefsName, Context.MODE_PRIVATE).getString(key, null)

    fun writeSnapshot(context: Context, prefsName: String, key: String, json: String?) {
        val editor = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE).edit()
        if (json == null) editor.remove(key) else editor.putString(key, json)
        editor.commit()
    }
}

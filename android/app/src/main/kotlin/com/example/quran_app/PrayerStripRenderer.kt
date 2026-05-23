package com.example.quran_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat

/** Builds the ongoing prayer-strip notification from a [PrayerStripState] snapshot. */
class PrayerStripRenderer(private val context: Context) {

    fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Prayer times strip",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Ongoing pinned strip showing today's prayer schedule"
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        manager.createNotificationChannel(channel)
    }

    fun build(state: PrayerStripState): Notification {
        val expanded = RemoteViews(context.packageName, R.layout.prayer_strip_expanded)
        val collapsed = RemoteViews(context.packageName, R.layout.prayer_strip_collapsed)

        // Header: hijri date + weekday. App name is shown by the system notification frame.
        expanded.setTextViewText(R.id.strip_hijri, state.hijriDateLabel)
        val weekdayText = state.weekdayLabel
        expanded.setTextViewText(R.id.strip_weekday, weekdayText)
        val weekdayColor =
            if (state.isFriday) context.resources.getColor(R.color.strip_accent, null)
            else context.resources.getColor(R.color.strip_text_muted, null)
        expanded.setTextColor(R.id.strip_weekday, weekdayColor)

        val labelIds = intArrayOf(
            R.id.cell_0_label, R.id.cell_1_label, R.id.cell_2_label,
            R.id.cell_3_label, R.id.cell_4_label, R.id.cell_5_label
        )
        val timeIds = intArrayOf(
            R.id.cell_0_time, R.id.cell_1_time, R.id.cell_2_time,
            R.id.cell_3_time, R.id.cell_4_time, R.id.cell_5_time
        )

        // Color tokens, resolved once.
        val primary = context.resources.getColor(R.color.strip_text_primary, null)
        val muted = context.resources.getColor(R.color.strip_text_muted, null)
        val dim = context.resources.getColor(R.color.strip_text_dim, null)
        val accentTextOnPill = context.resources.getColor(R.color.strip_text_primary, null)

        for (i in 0 until 6) {
            val cell = state.cells.getOrNull(i) ?: continue
            expanded.setTextViewText(labelIds[i], cell.label)
            expanded.setTextViewText(timeIds[i], cell.time)

            when {
                // Active prayer (next): label snow-bold, time wrapped in deep-teal pill.
                i == state.nextPrayerIndex -> {
                    expanded.setTextColor(labelIds[i], primary)
                    expanded.setTextColor(timeIds[i], accentTextOnPill)
                    expanded.setInt(
                        timeIds[i], "setBackgroundResource", R.drawable.strip_time_pill
                    )
                }
                // Passed prayer: dim everything.
                i < state.nextPrayerIndex -> {
                    expanded.setTextColor(labelIds[i], dim)
                    expanded.setTextColor(timeIds[i], dim)
                    expanded.setInt(timeIds[i], "setBackgroundResource", 0)
                }
                // Future prayer: primary label, muted time, no pill.
                else -> {
                    expanded.setTextColor(labelIds[i], primary)
                    expanded.setTextColor(timeIds[i], muted)
                    expanded.setInt(timeIds[i], "setBackgroundResource", 0)
                }
            }
        }

        // Collapsed view: just the hijri date with crescent moon.
        collapsed.setTextViewText(R.id.collapsed_hijri, state.hijriDateLabel)

        val launchPI = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCustomContentView(collapsed)
            .setCustomBigContentView(expanded)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setContentIntent(launchPI)
            .build()
    }

    companion object {
        const val CHANNEL_ID = "prayer_strip_channel"
        const val NOTIFICATION_ID = 100
    }
}

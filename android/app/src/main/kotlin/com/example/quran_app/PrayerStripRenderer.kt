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
        // Collapsed and expanded layouts are identical (6-cell strip).
        // Bind both with the same cell data.
        val collapsed = RemoteViews(context.packageName, R.layout.prayer_strip_collapsed)
        val expanded = RemoteViews(context.packageName, R.layout.prayer_strip_expanded)
        bindCells(collapsed, state)
        bindCells(expanded, state)

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

    private fun bindCells(views: RemoteViews, state: PrayerStripState) {
        val labelIds = intArrayOf(
            R.id.cell_0_label, R.id.cell_1_label, R.id.cell_2_label,
            R.id.cell_3_label, R.id.cell_4_label, R.id.cell_5_label
        )
        val timeIds = intArrayOf(
            R.id.cell_0_time, R.id.cell_1_time, R.id.cell_2_time,
            R.id.cell_3_time, R.id.cell_4_time, R.id.cell_5_time
        )

        // Color tokens resolved through the app's resources — values/colors.xml +
        // values-night/colors.xml provide light/dark variants automatically.
        val primary = context.resources.getColor(R.color.strip_text_primary, null)
        val muted = context.resources.getColor(R.color.strip_text_muted, null)
        val dim = context.resources.getColor(R.color.strip_text_dim, null)
        // Pill is always teal; its text is always light for contrast on both themes.
        val pillText = context.resources.getColor(R.color.strip_pill_text, null)

        for (i in 0 until 6) {
            val cell = state.cells.getOrNull(i) ?: continue
            views.setTextViewText(labelIds[i], cell.label)
            views.setTextViewText(timeIds[i], cell.time)

            when {
                i == state.nextPrayerIndex -> {
                    views.setTextColor(labelIds[i], primary)
                    views.setTextColor(timeIds[i], pillText)
                    views.setInt(timeIds[i], "setBackgroundResource", R.drawable.strip_time_pill)
                }
                i < state.nextPrayerIndex -> {
                    views.setTextColor(labelIds[i], dim)
                    views.setTextColor(timeIds[i], dim)
                    views.setInt(timeIds[i], "setBackgroundResource", 0)
                }
                else -> {
                    views.setTextColor(labelIds[i], primary)
                    views.setTextColor(timeIds[i], muted)
                    views.setInt(timeIds[i], "setBackgroundResource", 0)
                }
            }
        }
    }

    companion object {
        const val CHANNEL_ID = "prayer_strip_channel"
        const val NOTIFICATION_ID = 100
    }
}

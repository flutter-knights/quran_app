package com.example.quran_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.Typeface
import android.os.Build
import android.text.SpannableString
import android.text.Spannable
import android.text.style.StyleSpan
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat

/** Builds the ongoing prayer-strip notification for a single [PrayerStripDay]. */
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

    fun build(day: PrayerStripDay, nextIndex: Int): Notification {
        val collapsed = RemoteViews(context.packageName, R.layout.prayer_strip_collapsed)
        val expanded = RemoteViews(context.packageName, R.layout.prayer_strip_expanded)
        bindCells(collapsed, day, nextIndex)
        bindCells(expanded, day, nextIndex)

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

    private fun bindCells(views: RemoteViews, day: PrayerStripDay, nextIndex: Int) {
        val labelIds = intArrayOf(
            R.id.cell_0_label, R.id.cell_1_label, R.id.cell_2_label,
            R.id.cell_3_label, R.id.cell_4_label
        )
        val timeIds = intArrayOf(
            R.id.cell_0_time, R.id.cell_1_time, R.id.cell_2_time,
            R.id.cell_3_time, R.id.cell_4_time
        )

        val primary = context.resources.getColor(R.color.strip_text_primary, null)
        val muted = context.resources.getColor(R.color.strip_text_muted, null)
        val dim = context.resources.getColor(R.color.strip_text_dim, null)
        val pillText = context.resources.getColor(R.color.strip_pill_text, null)
        val accent = day.accentColor
            ?: context.resources.getColor(R.color.strip_accent, null)

        for (i in 0 until 5) {
            val cell = day.cells.getOrNull(i) ?: continue
            views.setTextViewText(labelIds[i], cell.label)
            views.setTextViewText(timeIds[i], cell.time)

            when {
                i == nextIndex -> {
                    views.setTextViewText(labelIds[i], boldLabel(cell.label))
                    views.setTextColor(labelIds[i], primary)
                    views.setTextColor(timeIds[i], pillText)
                    applyAccentPill(views, timeIds[i], accent)
                }
                i < nextIndex -> {
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

    /** Renders [text] in bold via a parcelable [StyleSpan] (survives RemoteViews). */
    private fun boldLabel(text: String): SpannableString =
        SpannableString(text).apply {
            setSpan(StyleSpan(Typeface.BOLD), 0, length, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
        }

    /**
     * Paints the next-prayer pill with the live [accent] color.
     *
     * RemoteViews can't carry a tinted [android.graphics.drawable.Drawable], and
     * the only remotable way to tint a *rounded* background — `setBackgroundTintList`
     * via [RemoteViews.setColorStateList] — exists on API 31+ only. So:
     *  - API 31+ : keep the rounded `strip_time_pill` drawable and tint it.
     *  - API < 31: flat `setBackgroundColor` (square) + re-apply the drawable's
     *              padding manually, since a flat ColorDrawable carries none.
     */
    private fun applyAccentPill(views: RemoteViews, timeId: Int, accent: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setInt(timeId, "setBackgroundResource", R.drawable.strip_time_pill)
            views.setColorStateList(
                timeId, "setBackgroundTintList", ColorStateList.valueOf(accent)
            )
        } else {
            views.setInt(timeId, "setBackgroundColor", accent)
            val density = context.resources.displayMetrics.density
            val padH = (8 * density).toInt()
            val padV = (2 * density).toInt()
            views.setViewPadding(timeId, padH, padV, padH, padV)
        }
    }

    companion object {
        const val CHANNEL_ID = "prayer_strip_channel"
        const val NOTIFICATION_ID = 100
    }
}

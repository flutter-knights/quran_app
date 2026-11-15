package com.example.quran_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Typeface
import android.os.Build
import android.text.SpannableString
import android.text.Spannable
import android.text.style.StyleSpan
import android.view.View
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

    fun build(day: PrayerStripDay, nextIndex: Int, nextAt: Long?, style: StripStyleNative): Notification {
        val night = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        val collapsed = RemoteViews(context.packageName, R.layout.prayer_strip_collapsed)
        bindCells(collapsed, day, nextIndex, style, night, CELL_IDS)

        val launchPI = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCustomContentView(collapsed)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setContentIntent(launchPI)

        if (style.expanded) {
            val expanded = RemoteViews(context.packageName, R.layout.prayer_strip_expanded)
            bindCells(expanded, day, nextIndex, style, night, ROW_IDS)
            bindExpandedExtras(expanded, day, nextIndex, style, night)
            builder.setCustomBigContentView(expanded)
        }

        val nextCell = day.cells.getOrNull(nextIndex)
        if (style.countdown && nextAt != null && nextCell != null) {
            builder.setWhen(nextAt)
                .setUsesChronometer(true)
                .setChronometerCountDown(true)
                .setShowWhen(true)
                .setSubText(nextCell.nextLabel.ifEmpty { null })
        } else {
            builder.setShowWhen(false)
        }
        return builder.build()
    }

    private fun bindCells(
        views: RemoteViews,
        day: PrayerStripDay,
        nextIndex: Int,
        style: StripStyleNative,
        night: Boolean,
        highlightIds: IntArray,
    ) {
        val primary = context.resources.getColor(R.color.strip_text_primary, null)
        val muted = style.mutedText(night, context.resources.getColor(R.color.strip_text_muted, null))
        val passed = StripStyleNative.passed(primary)
        applyBackground(views, style, night)

        for (i in 0 until 5) {
            val cell = day.cells.getOrNull(i) ?: continue
            views.setTextViewText(LABEL_IDS[i], cell.label)
            views.setTextViewText(TIME_IDS[i], cell.time)
            when {
                i == nextIndex -> {
                    val text = style.nextTextColor(night, TINTABLE)
                    views.setTextViewText(LABEL_IDS[i], bold(cell.label))
                    views.setTextColor(LABEL_IDS[i], text)
                    views.setTextColor(TIME_IDS[i], text)
                    applyHighlight(views, highlightIds[i], style, night)
                }
                nextIndex < 0 || i < nextIndex -> {
                    views.setTextColor(LABEL_IDS[i], passed)
                    views.setTextColor(TIME_IDS[i], passed)
                }
                else -> {
                    views.setTextColor(LABEL_IDS[i], primary)
                    views.setTextColor(TIME_IDS[i], muted)
                }
            }
        }
    }

    private fun bindExpandedExtras(
        views: RemoteViews,
        day: PrayerStripDay,
        nextIndex: Int,
        style: StripStyleNative,
        night: Boolean,
    ) {
        val date = listOf(day.weekdayLabel, day.hijriDateLabel).filter { it.isNotEmpty() }.joinToString(" · ")
        views.setTextViewText(R.id.strip_date, date)
        views.setTextColor(
            R.id.strip_date,
            style.mutedText(night, context.resources.getColor(R.color.strip_text_muted, null)),
        )
        for (i in 0 until 5) {
            val showTag = i == nextIndex && day.nextTag.isNotEmpty()
            views.setViewVisibility(TAG_IDS[i], if (showTag) View.VISIBLE else View.GONE)
            if (showTag) {
                views.setTextViewText(TAG_IDS[i], day.nextTag)
                views.setTextColor(TAG_IDS[i], style.nextTextColor(night, TINTABLE))
            }
        }
    }

    private fun bold(text: String): SpannableString =
        SpannableString(text).apply {
            setSpan(StyleSpan(Typeface.BOLD), 0, length, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
        }

    private fun applyHighlight(views: RemoteViews, id: Int, style: StripStyleNative, night: Boolean) {
        val drawable = when (style.shape) {
            "rounded" -> R.drawable.strip_time_pill
            "pill" -> R.drawable.strip_cell_pill
            "outline" -> R.drawable.strip_cell_outline
            else -> return
        }
        val color = style.highlight(night)
        if (TINTABLE) {
            views.setInt(id, "setBackgroundResource", drawable)
            views.setColorStateList(id, "setBackgroundTintList", ColorStateList.valueOf(color))
        } else {
            views.setInt(id, "setBackgroundColor", color)
        }
    }

    private fun applyBackground(views: RemoteViews, style: StripStyleNative, night: Boolean) {
        val color = style.background(night) ?: return
        if (TINTABLE) {
            views.setInt(R.id.strip_root, "setBackgroundResource", R.drawable.strip_notification_bg)
            views.setColorStateList(R.id.strip_root, "setBackgroundTintList", ColorStateList.valueOf(color))
        } else {
            views.setInt(R.id.strip_root, "setBackgroundColor", color)
        }
        val padH = (4 * context.resources.displayMetrics.density).toInt()
        val padV = (2 * context.resources.displayMetrics.density).toInt()
        views.setViewPadding(R.id.strip_root, padH, padV, padH, padV)
    }

    companion object {
        const val CHANNEL_ID = "prayer_strip_channel"
        const val NOTIFICATION_ID = 100

        private val TINTABLE = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S

        private val LABEL_IDS = intArrayOf(
            R.id.cell_0_label, R.id.cell_1_label, R.id.cell_2_label, R.id.cell_3_label, R.id.cell_4_label
        )
        private val TIME_IDS = intArrayOf(
            R.id.cell_0_time, R.id.cell_1_time, R.id.cell_2_time, R.id.cell_3_time, R.id.cell_4_time
        )
        private val TAG_IDS = intArrayOf(
            R.id.cell_0_tag, R.id.cell_1_tag, R.id.cell_2_tag, R.id.cell_3_tag, R.id.cell_4_tag
        )
        private val CELL_IDS = intArrayOf(R.id.cell_0, R.id.cell_1, R.id.cell_2, R.id.cell_3, R.id.cell_4)
        private val ROW_IDS = intArrayOf(R.id.row_0, R.id.row_1, R.id.row_2, R.id.row_3, R.id.row_4)
    }
}

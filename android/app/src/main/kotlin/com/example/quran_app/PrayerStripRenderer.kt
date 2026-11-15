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

    fun build(window: PrayerStripWindow, day: PrayerStripDay, nextIndex: Int, nextAt: Long?): Notification {
        val style = window.style
        val night = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        val paint = Paint(
            night = night,
            nextDay = style.nextTextColor(night = false, tintable = TINTABLE),
            nextNight = style.nextTextColor(night = true, tintable = TINTABLE),
            mutedDay = style.mutedText(night = false, default = colorIn(night = false, R.color.strip_text_muted)),
            mutedNight = style.mutedText(night = true, default = colorIn(night = true, R.color.strip_text_muted)),
        )
        val collapsed = RemoteViews(context.packageName, R.layout.prayer_strip_collapsed)
        bindCells(collapsed, day, nextIndex, style, paint, CELL_IDS, expanded = false)

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
            bindCells(expanded, day, nextIndex, style, paint, ROW_IDS, expanded = true)
            bindExpandedExtras(expanded, day, nextIndex, window.nextTag, style, paint)
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

    private data class Paint(
        val night: Boolean,
        val nextDay: Int,
        val nextNight: Int,
        val mutedDay: Int,
        val mutedNight: Int,
    )

    private fun bindCells(
        views: RemoteViews,
        day: PrayerStripDay,
        nextIndex: Int,
        style: StripStyleNative,
        paint: Paint,
        highlightIds: IntArray,
        expanded: Boolean,
    ) {
        applyBackground(views, style, paint)
        for (i in 0 until 5) {
            val cell = day.cells.getOrNull(i) ?: continue
            views.setTextViewText(LABEL_IDS[i], cell.label)
            views.setTextViewText(TIME_IDS[i], if (expanded) cell.timeFull else cell.time)
            when (StripCellRole.of(i, nextIndex)) {
                StripCellRole.NEXT -> {
                    views.setTextViewText(LABEL_IDS[i], bold(cell.label))
                    setDayNightText(views, LABEL_IDS[i], paint.nextDay, paint.nextNight, paint.night)
                    setDayNightText(views, TIME_IDS[i], paint.nextDay, paint.nextNight, paint.night)
                    applyHighlight(views, highlightIds[i], style, paint.night)
                }
                StripCellRole.PASSED -> {
                    views.setBoolean(LABEL_IDS[i], "setEnabled", false)
                    views.setBoolean(TIME_IDS[i], "setEnabled", false)
                }
                StripCellRole.UPCOMING -> Unit
            }
        }
    }

    private fun bindExpandedExtras(
        views: RemoteViews,
        day: PrayerStripDay,
        nextIndex: Int,
        nextTag: String,
        style: StripStyleNative,
        paint: Paint,
    ) {
        val date = listOf(day.weekdayLabel, day.hijriDateLabel).filter { it.isNotEmpty() }.joinToString(" · ")
        views.setTextViewText(R.id.strip_date, date)
        if (style.backgroundDay != null || style.backgroundNight != null) {
            setDayNightText(views, R.id.strip_date, paint.mutedDay, paint.mutedNight, paint.night)
        }
        for (i in 0 until 5) {
            val showTag = i == nextIndex && nextTag.isNotEmpty()
            views.setViewVisibility(TAG_IDS[i], if (showTag) View.VISIBLE else View.GONE)
            if (showTag) {
                views.setTextViewText(TAG_IDS[i], nextTag)
                setDayNightText(views, TAG_IDS[i], paint.nextDay, paint.nextNight, paint.night)
            }
        }
    }

    private fun setDayNightText(views: RemoteViews, id: Int, day: Int, night: Int, isNight: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setColorInt(id, "setTextColor", day, night)
        } else {
            views.setTextColor(id, if (isNight) night else day)
        }
    }

    private fun colorIn(night: Boolean, res: Int): Int {
        val config = Configuration(context.resources.configuration).apply {
            uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
                if (night) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO
        }
        return context.createConfigurationContext(config).getColor(res)
    }

    private fun bold(text: String): SpannableString =
        SpannableString(text).apply {
            setSpan(StyleSpan(Typeface.BOLD), 0, length, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
        }

    private fun applyHighlight(views: RemoteViews, id: Int, style: StripStyleNative, night: Boolean) {
        val drawable = when (style.shape) {
            StripShape.ROUNDED -> R.drawable.strip_time_pill
            StripShape.PILL -> R.drawable.strip_cell_pill
            StripShape.OUTLINE -> R.drawable.strip_cell_outline
            StripShape.NONE -> return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setInt(id, "setBackgroundResource", drawable)
            views.setColorStateList(
                id, "setBackgroundTintList",
                ColorStateList.valueOf(style.highlightDay), ColorStateList.valueOf(style.highlightNight),
            )
        } else {
            views.setInt(id, "setBackgroundColor", style.highlight(night))
        }
    }

    private fun applyBackground(views: RemoteViews, style: StripStyleNative, paint: Paint) {
        if (style.backgroundDay == null && style.backgroundNight == null) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setInt(R.id.strip_root, "setBackgroundResource", R.drawable.strip_notification_bg)
            views.setColorStateList(
                R.id.strip_root, "setBackgroundTintList",
                ColorStateList.valueOf(style.backgroundDay ?: 0), ColorStateList.valueOf(style.backgroundNight ?: 0),
            )
        } else {
            views.setInt(R.id.strip_root, "setBackgroundColor", style.background(paint.night) ?: 0)
        }
        val padH = (4 * context.resources.displayMetrics.density).toInt()
        views.setViewPadding(R.id.strip_root, padH, 0, padH, 0)
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

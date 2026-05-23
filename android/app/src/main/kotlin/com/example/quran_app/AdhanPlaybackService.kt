package com.example.quran_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground service that plays one adhan and shows an ongoing notification.
 *
 * Why a service (not a plain notification with sound)?
 * - flutter_local_notifications routes audio through the notification-sound
 *   system, which Android can interrupt when the user expands the shade.
 * - MediaPlayer on STREAM_ALARM is independent media playback. Audio continues
 *   even when the user interacts with the shade.
 *
 * Lifecycle:
 *   ACTION_PLAY → start foreground, post ongoing notification, start MediaPlayer.
 *   ACTION_STOP → stop player, cancel notification, stopSelf.
 *   onCompletion (audio finished) → release player, KEEP notification + service
 *                                    alive until user dismisses (per spec §6.3).
 */
class AdhanPlaybackService : Service() {

    private var mediaPlayer: MediaPlayer? = null
    private var currentPrayer: String? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> handlePlay(intent)
            ACTION_STOP -> handleStop(reason = "user_stop")
            else -> {
                Log.w(TAG, "onStartCommand: unknown action ${intent?.action}")
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun handlePlay(intent: Intent) {
        val prayer = intent.getStringExtra(EXTRA_PRAYER) ?: "fajr"
        val clipName = intent.getStringExtra(EXTRA_CLIP) ?: "normal_adhan"
        val localeCode = intent.getStringExtra(EXTRA_LOCALE) ?: "en"
        currentPrayer = prayer

        Log.i(TAG, "onStartCommand action=ACTION_PLAY prayer=$prayer clip=$clipName")

        ensureChannel()

        val notif = buildNotification(prayer, localeCode)
        startForeground(NOTIFICATION_ID, notif)

        startMediaPlayer(clipName)
    }

    private fun startMediaPlayer(clipName: String) {
        val resId = resources.getIdentifier(clipName, "raw", packageName)
        if (resId == 0) {
            Log.e(TAG, "startMediaPlayer: R.raw.$clipName not found")
            return
        }

        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        mediaPlayer = MediaPlayer().apply {
            setAudioAttributes(attrs)
            try {
                val afd = resources.openRawResourceFd(resId)
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
                prepare()
                start()
                Log.i(TAG, "MediaPlayer started clip=$clipName")
            } catch (e: Exception) {
                Log.e(TAG, "MediaPlayer setup failed", e)
                release()
                mediaPlayer = null
                return
            }
            setOnCompletionListener {
                Log.i(TAG, "MediaPlayer onCompletion (released, notification kept)")
                it.release()
                mediaPlayer = null
                // Notification + service stay alive; user must Stop or swipe.
            }
            setOnErrorListener { _, what, extra ->
                Log.e(TAG, "MediaPlayer onError what=$what extra=$extra")
                false
            }
        }
    }

    private fun handleStop(reason: String) {
        Log.i(TAG, "dismissed reason=$reason prayer=$currentPrayer")
        mediaPlayer?.let {
            try { it.stop() } catch (_: IllegalStateException) {}
            it.release()
        }
        mediaPlayer = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        Log.i(TAG, "onDestroy")
        mediaPlayer?.let {
            try { it.stop() } catch (_: IllegalStateException) {}
            it.release()
        }
        mediaPlayer = null
        super.onDestroy()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Prayer adhan",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Plays the adhan at each prayer time"
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(prayer: String, localeCode: String): android.app.Notification {
        val ctx = localizedContext(localeCode)

        val titleResId = ctx.resources.getIdentifier(
            "adhan_title_$prayer", "string", packageName
        ).let { if (it != 0) it else R.string.adhan_title_fajr }
        val bodyResId = ctx.resources.getIdentifier(
            "adhan_body_$prayer", "string", packageName
        ).let { if (it != 0) it else R.string.adhan_body_fajr }
        val title = ctx.getString(titleResId)
        val body = ctx.getString(bodyResId)
        val stopLabel = ctx.getString(R.string.adhan_stop)

        val openPI = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, AdhanPlaybackService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPI = PendingIntent.getService(
            this, 1, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setOngoing(true)
            .setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(openPI)
            .setDeleteIntent(stopPI)
            .addAction(R.drawable.ic_adhan_stop, stopLabel, stopPI)
            .build()
    }

    /**
     * Returns a Context whose resources are bound to the requested locale —
     * so the notification title/body always match the app's language, not the
     * system locale (which may differ).
     */
    private fun localizedContext(localeCode: String): Context {
        val locale = java.util.Locale(localeCode)
        java.util.Locale.setDefault(locale)
        val config = Configuration(resources.configuration)
        config.setLocale(locale)
        return createConfigurationContext(config)
    }

    companion object {
        private const val TAG = "AdhanService"
        const val CHANNEL_ID = "prayer_adhan_channel"
        const val NOTIFICATION_ID = 200

        const val ACTION_PLAY = "com.example.quran_app.ACTION_ADHAN_PLAY"
        const val ACTION_STOP = "com.example.quran_app.ACTION_ADHAN_STOP"

        const val EXTRA_PRAYER = "prayer"
        const val EXTRA_CLIP = "clip"
        const val EXTRA_LOCALE = "locale"
    }
}

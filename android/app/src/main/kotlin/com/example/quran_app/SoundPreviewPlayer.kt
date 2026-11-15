package com.example.quran_app

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Handler
import android.os.Looper
import android.util.Log

object SoundPreviewPlayer {

    private const val TAG = "SoundPreview"
    private var player: MediaPlayer? = null
    private var onEnded: ((String) -> Unit)? = null
    private val main = Handler(Looper.getMainLooper())

    @Synchronized
    fun play(context: Context, sound: String, prayer: String, onEnded: (String) -> Unit) {
        stop()
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val mp = MediaPlayer()
        try {
            mp.setAudioAttributes(attrs)
            when (sound) {
                "adhan" -> {
                    val resId = context.resources.getIdentifier(AlertPlanner.clipFor(prayer), "raw", context.packageName)
                    if (resId == 0) throw IllegalStateException("missing clip for $prayer")
                    context.resources.openRawResourceFd(resId).use { mp.setDataSource(it.fileDescriptor, it.startOffset, it.length) }
                }
                "tone" -> {
                    val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                        ?: throw IllegalStateException("no default notification sound")
                    mp.setDataSource(context, uri)
                }
                else -> throw IllegalArgumentException("no preview for $sound")
            }
            mp.setOnCompletionListener { finish(it, sound) }
            mp.setOnErrorListener { p, _, _ ->
                finish(p, sound)
                true
            }
            mp.prepare()
            mp.start()
            player = mp
            this.onEnded = onEnded
        } catch (e: Exception) {
            Log.w(TAG, "play failed sound=$sound prayer=$prayer", e)
            mp.release()
            main.post { onEnded(sound) }
        }
    }

    @Synchronized
    fun stop() {
        player?.let {
            try {
                it.stop()
            } catch (_: IllegalStateException) {
            }
            it.release()
        }
        player = null
        onEnded = null
    }

    @Synchronized
    private fun finish(mp: MediaPlayer, sound: String) {
        mp.release()
        if (player !== mp) return
        player = null
        val callback = onEnded ?: return
        onEnded = null
        main.post { callback(sound) }
    }
}

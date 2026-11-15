package com.example.quran_app

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.util.Log

object SoundPreviewPlayer {

    private const val TAG = "SoundPreview"
    private var player: MediaPlayer? = null

    @Synchronized
    fun play(context: Context, sound: String, prayer: String) {
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
            mp.setOnCompletionListener { release(it) }
            mp.setOnErrorListener { p, _, _ ->
                release(p)
                true
            }
            mp.prepare()
            mp.start()
            player = mp
        } catch (e: Exception) {
            Log.w(TAG, "play failed sound=$sound prayer=$prayer", e)
            mp.release()
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
    }

    @Synchronized
    private fun release(mp: MediaPlayer) {
        mp.release()
        if (player === mp) player = null
    }
}

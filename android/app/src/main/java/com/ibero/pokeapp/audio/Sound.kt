package com.ibero.pokeapp.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.media.MediaPlayer
import android.media.PlaybackParams
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.edit
import com.ibero.pokeapp.ui.theme.Sprites
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.sin
import kotlin.random.Random

/** Chiptune effects synthesized at startup; no audio files in the project. */
enum class Sfx { Select, Confirm, Hit, SuperHit, WeakHit, Miss, Faint, BallOpen, Throw, Join, Victory, Defeat, Card }

object Sound {
    private const val RATE = 22050
    private const val PREF_MUTED = "muted"

    private lateinit var appContext: Context
    private val tracks = mutableMapOf<Sfx, AudioTrack>()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    var muted by mutableStateOf(false)
        private set

    private val attributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_GAME)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    fun init(context: Context) {
        appContext = context.applicationContext
        muted = prefs().getBoolean(PREF_MUTED, false)
        scope.launch { Sfx.entries.forEach { sfx -> tracks[sfx] = buildTrack(synth(sfx)) } }
    }

    fun toggleMute() {
        muted = !muted
        prefs().edit { putBoolean(PREF_MUTED, muted) }
    }

    fun play(sfx: Sfx) {
        if (muted) return
        val track = tracks[sfx] ?: return
        runCatching {
            if (track.playState == AudioTrack.PLAYSTATE_PLAYING) track.stop()
            track.reloadStaticData()
            track.play()
        }
    }

    /** Streams the Pokémon's real cry from PokeAPI. A lower pitch is used when it faints. */
    fun cry(pokemonId: Int, pitch: Float = 1f) {
        if (muted) return
        val player = MediaPlayer()
        runCatching {
            player.setAudioAttributes(attributes)
            player.setDataSource(Sprites.cry(pokemonId))
            player.setVolume(0.6f, 0.6f)
            player.setOnPreparedListener {
                if (pitch != 1f) runCatching { it.playbackParams = PlaybackParams().setPitch(pitch).setSpeed(pitch) }
                it.start()
            }
            player.setOnCompletionListener { it.release() }
            player.setOnErrorListener { mp, _, _ -> mp.release(); true }
            player.prepareAsync()
        }.onFailure { player.release() }
    }

    private fun prefs() = appContext.getSharedPreferences("pokeapp_prefs", Context.MODE_PRIVATE)

    private fun buildTrack(samples: ShortArray): AudioTrack {
        val track = AudioTrack.Builder()
            .setAudioAttributes(attributes)
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(RATE)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setTransferMode(AudioTrack.MODE_STATIC)
            .setBufferSizeInBytes(samples.size * 2)
            .build()
        track.write(samples, 0, samples.size)
        return track
    }

    // ---------- Synthesis ----------

    private class Builder {
        val data = ArrayList<Float>()

        /** Square-wave note sweeping from [f0] to [f1] Hz. */
        fun tone(f0: Double, f1: Double = f0, ms: Int, vol: Float = 0.35f, duty: Double = 0.5) {
            val n = RATE * ms / 1000
            var phase = 0.0
            for (i in 0 until n) {
                val t = i.toDouble() / n
                val f = f0 + (f1 - f0) * t
                phase += f / RATE
                val sq = if (phase % 1.0 < duty) 1f else -1f
                val env = (1 - t).toFloat().coerceAtLeast(0.15f)
                data += sq * vol * env
            }
        }

        fun noise(ms: Int, vol: Float = 0.5f, decay: Double = 5.0) {
            val n = RATE * ms / 1000
            var held = 0f
            for (i in 0 until n) {
                if (i % 3 == 0) held = Random.nextFloat() * 2 - 1
                data += held * vol * exp(-decay * i / n).toFloat()
            }
        }

        fun sine(f0: Double, f1: Double, ms: Int, vol: Float = 0.4f) {
            val n = RATE * ms / 1000
            var phase = 0.0
            for (i in 0 until n) {
                val t = i.toDouble() / n
                phase += (f0 + (f1 - f0) * t) / RATE
                data += (sin(2 * PI * phase) * vol * (1 - t)).toFloat()
            }
        }

        fun rest(ms: Int) = repeat(RATE * ms / 1000) { data += 0f }

        fun build() = ShortArray(data.size) { (data[it].coerceIn(-1f, 1f) * Short.MAX_VALUE).toInt().toShort() }
    }

    private fun synth(sfx: Sfx): ShortArray = Builder().apply {
        when (sfx) {
            Sfx.Select -> tone(1320.0, ms = 45, vol = 0.25f)
            Sfx.Confirm -> { tone(880.0, ms = 60, vol = 0.25f); tone(1320.0, ms = 90, vol = 0.25f) }
            Sfx.Card -> { noise(60, 0.25f, 3.0); tone(660.0, 990.0, 70, 0.2f) }
            Sfx.Hit -> { noise(140, 0.6f); tone(180.0, 90.0, 60, 0.3f) }
            Sfx.SuperHit -> { noise(90, 0.7f); rest(20); noise(180, 0.8f, 4.0); tone(220.0, 70.0, 90, 0.35f) }
            Sfx.WeakHit -> noise(90, 0.3f, 7.0)
            Sfx.Miss -> sine(900.0, 300.0, 220, 0.3f)
            Sfx.Faint -> tone(700.0, 110.0, 650, 0.3f, duty = 0.25)
            Sfx.Throw -> sine(300.0, 1200.0, 260, 0.3f)
            Sfx.BallOpen -> { noise(50, 0.4f, 2.0); tone(523.0, 1568.0, 160, 0.25f, duty = 0.25) }
            Sfx.Join -> { tone(784.0, ms = 80); tone(988.0, ms = 80); tone(1175.0, ms = 160) }
            Sfx.Victory -> {
                listOf(523.0, 659.0, 784.0, 1047.0).forEach { tone(it, ms = 110, duty = 0.25) }
                rest(40); tone(784.0, ms = 110, duty = 0.25); tone(1047.0, ms = 380, duty = 0.25)
            }
            Sfx.Defeat -> listOf(659.0, 587.0, 523.0, 392.0).forEach { tone(it, ms = 200, vol = 0.3f, duty = 0.25) }
        }
    }.build()
}

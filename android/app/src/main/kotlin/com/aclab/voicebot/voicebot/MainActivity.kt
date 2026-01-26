package com.aclab.voicebot.voicebot

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var audioTrack: AudioTrack? = null
    private val audioChannelName = "voicebot/audio_player"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.i("XIAOZHI", "[XIAOZHI] MainActivity onCreate")
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
        Log.i("XIAOZHI", "[XIAOZHI] Mic permission granted=$granted")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, audioChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "init" -> {
                        val sampleRate = call.argument<Int>("sampleRate") ?: 16000
                        val channels = call.argument<Int>("channels") ?: 1
                        val bufferSize = call.argument<Int>("bufferSize") ?: 8192
                        initAudioTrack(sampleRate, channels, bufferSize)
                        result.success(null)
                    }
                    "write" -> {
                        val data = call.arguments as? ByteArray
                        if (data != null) {
                            audioTrack?.write(data, 0, data.size, AudioTrack.WRITE_BLOCKING)
                        }
                        result.success(null)
                    }
                    "getPlaybackHeadPosition" -> {
                        val position = audioTrack?.playbackHeadPosition ?: 0
                        result.success(position)
                    }
                    "stop" -> {
                        audioTrack?.stop()
                        result.success(null)
                    }
                    "release" -> {
                        audioTrack?.release()
                        audioTrack = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun initAudioTrack(sampleRate: Int, channels: Int, bufferSize: Int) {
        audioTrack?.release()
        val channelConfig =
            if (channels == 1) AudioFormat.CHANNEL_OUT_MONO else AudioFormat.CHANNEL_OUT_STEREO
        val minBuffer = AudioTrack.getMinBufferSize(
            sampleRate,
            channelConfig,
            AudioFormat.ENCODING_PCM_16BIT
        )
        val finalBufferSize = maxOf(minBuffer * 2, bufferSize)
        audioTrack = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setChannelMask(channelConfig)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .build()
            )
            .setBufferSizeInBytes(finalBufferSize)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
        audioTrack?.play()
    }
}

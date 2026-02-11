package com.aclab.voicebot.voicebot

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.util.Log
import android.provider.Settings
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.net.NetworkInterface
import java.util.Locale
import java.io.File
import android.content.Intent
import android.net.Uri

class MainActivity : FlutterActivity() {
    private var audioTrack: AudioTrack? = null
    private val audioChannelName = "voicebot/audio_player"
    private val otaChannelName = "voicebot/ota"
    private val updateChannelName = "voicebot/update"

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, otaChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installFirmware" -> {
                        // Not implemented in this client build.
                        result.success(null)
                    }
                    "restartApp" -> {
                        // Not implemented in this client build.
                        result.success(null)
                    }
                    "getDeviceId" -> {
                        val androidId = Settings.Secure.getString(
                            contentResolver,
                            Settings.Secure.ANDROID_ID
                        )
                        result.success(androidId)
                    }
                    "getMacAddress" -> {
                        result.success(getWifiMacAddress())
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updateChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("INVALID_PATH", "Missing apk path", null)
                            return@setMethodCallHandler
                        }
                        val file = File(path)
                        if (!file.exists()) {
                            result.error("MISSING_FILE", "APK file not found", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val uri: Uri = FileProvider.getUriForFile(
                                this,
                                "${applicationContext.packageName}.fileprovider",
                                file
                            )
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e("XIAOZHI", "Failed to launch installer", e)
                            result.error("INSTALL_FAILED", e.message, null)
                        }
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

    private fun getWifiMacAddress(): String? {
        val interfacesToCheck = listOf("wlan0", "wifi", "eth0")
        try {
            val interfaces = NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val nif = interfaces.nextElement()
                if (!interfacesToCheck.contains(nif.name.lowercase(Locale.US))) {
                    continue
                }
                val mac = nif.hardwareAddress ?: continue
                if (mac.isEmpty()) continue
                val sb = StringBuilder()
                for (i in mac.indices) {
                    if (i > 0) sb.append(':')
                    sb.append(String.format("%02X", mac[i]))
                }
                val value = sb.toString()
                if (value == "02:00:00:00:00:00" || value == "00:00:00:00:00:00") {
                    return null
                }
                return value
            }
        } catch (e: Exception) {
            Log.w("XIAOZHI", "Failed to read MAC address", e)
        }
        return null
    }
}

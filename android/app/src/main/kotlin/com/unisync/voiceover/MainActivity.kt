package com.unisync.voiceover

import android.content.ContentValues
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "voice_over/ringtone"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canWrite" -> result.success(canWriteSettings())
                    "requestWritePermission" -> {
                        openWriteSettings()
                        result.success(null)
                    }
                    "setAs" -> {
                        val path = call.argument<String>("path")
                        val type = call.argument<String>("type") ?: "ringtone"
                        if (path == null) {
                            result.error("BAD_ARGS", "Missing path", null)
                            return@setMethodCallHandler
                        }
                        if (!canWriteSettings()) {
                            openWriteSettings()
                            result.success("permission_needed")
                            return@setMethodCallHandler
                        }
                        try {
                            setAsTone(path, type)
                            result.success("ok")
                        } catch (e: Exception) {
                            result.error("SET_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun canWriteSettings(): Boolean = Settings.System.canWrite(this)

    private fun openWriteSettings() {
        val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun mimeFor(name: String): String = when {
        name.endsWith(".mp3", true) -> "audio/mpeg"
        name.endsWith(".m4a", true) -> "audio/mp4"
        name.endsWith(".aac", true) -> "audio/aac"
        name.endsWith(".wav", true) -> "audio/x-wav"
        else -> "audio/mpeg"
    }

    private fun setAsTone(path: String, type: String) {
        val file = File(path)
        val resolver = contentResolver

        val (ringtoneType, isColumn, relativeSub) = when (type) {
            "alarm" -> Triple(
                RingtoneManager.TYPE_ALARM,
                MediaStore.Audio.Media.IS_ALARM,
                "Alarms",
            )
            "notification" -> Triple(
                RingtoneManager.TYPE_NOTIFICATION,
                MediaStore.Audio.Media.IS_NOTIFICATION,
                "Notifications",
            )
            else -> Triple(
                RingtoneManager.TYPE_RINGTONE,
                MediaStore.Audio.Media.IS_RINGTONE,
                "Ringtones",
            )
        }

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, file.name)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeFor(file.name))
            put(MediaStore.MediaColumns.SIZE, file.length())
            put(MediaStore.Audio.Media.IS_RINGTONE, false)
            put(MediaStore.Audio.Media.IS_ALARM, false)
            put(MediaStore.Audio.Media.IS_NOTIFICATION, false)
            put(MediaStore.Audio.Media.IS_MUSIC, false)
            put(isColumn, true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    "Music/$relativeSub",
                )
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
        }

        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(
                MediaStore.VOLUME_EXTERNAL_PRIMARY,
            )
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }

        val uri: Uri = resolver.insert(collection, values)
            ?: throw IllegalStateException("Could not create media entry")

        resolver.openOutputStream(uri)?.use { out ->
            file.inputStream().use { input -> input.copyTo(out) }
        } ?: throw IllegalStateException("Could not open output stream")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val done = ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }
            resolver.update(uri, done, null, null)
        }

        RingtoneManager.setActualDefaultRingtoneUri(this, ringtoneType, uri)
    }
}

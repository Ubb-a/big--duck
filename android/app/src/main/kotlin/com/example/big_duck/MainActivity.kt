package com.example.big_duck

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val SHARE_METHOD_CHANNEL = "com.example.big_duck/share"
        private const val SHARE_EVENT_CHANNEL = "com.example.big_duck/share_events"
    }

    private var pendingInitialPaths: List<String> = emptyList()
    private var eventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val initial = extractSharedPaths(intent)
        if (initial.isNotEmpty()) {
            pendingInitialPaths = initial
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val incoming = extractSharedPaths(intent)
        if (incoming.isNotEmpty()) {
            val sink = eventSink
            if (sink != null) {
                sink.success(incoming)
            } else {
                pendingInitialPaths = pendingInitialPaths + incoming
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SHARE_METHOD_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "getInitialSharedFiles") {
                val files = pendingInitialPaths
                pendingInitialPaths = emptyList()
                result.success(files)
            } else {
                result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SHARE_EVENT_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    private fun extractSharedPaths(intent: Intent?): List<String> {
        if (intent == null) return emptyList()
        val uris = mutableListOf<Uri>()
        when (intent.action) {
            Intent.ACTION_SEND -> {
                val uri = getParcelableUri(intent, Intent.EXTRA_STREAM)
                if (uri != null) uris.add(uri)
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val list = getParcelableUriList(intent, Intent.EXTRA_STREAM)
                uris.addAll(list)
            }
        }
        if (uris.isEmpty()) return emptyList()
        return uris.mapNotNull { copyUriToInbox(it) }
    }

    @Suppress("DEPRECATION")
    private fun getParcelableUri(intent: Intent, key: String): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(key, Uri::class.java)
        } else {
            intent.getParcelableExtra(key)
        }
    }

    @Suppress("DEPRECATION")
    private fun getParcelableUriList(intent: Intent, key: String): List<Uri> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableArrayListExtra(key, Uri::class.java) ?: emptyList()
        } else {
            intent.getParcelableArrayListExtra<Uri>(key) ?: emptyList()
        }
    }

    private fun copyUriToInbox(uri: Uri): String? {
        return try {
            val rawName = resolveDisplayName(uri) ?: "shared_${System.currentTimeMillis()}"
            val safeName = rawName.replace(Regex("[\\\\/:*?\"<>|]"), "_").trim()
                .ifEmpty { "shared_${System.currentTimeMillis()}" }
            val batchDir = File(File(cacheDir, "shared_inbox"), System.currentTimeMillis().toString())
            if (!batchDir.exists()) {
                batchDir.mkdirs()
            }
            val destFile = File(batchDir, safeName)
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output)
                }
            } ?: return null
            if (destFile.exists() && destFile.length() > 0) destFile.absolutePath else null
        } catch (_: Exception) {
            null
        }
    }

    private fun resolveDisplayName(uri: Uri): String? {
        if (uri.scheme == "content") {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (idx >= 0) {
                            val name = cursor.getString(idx)
                            if (!name.isNullOrBlank()) return name
                        }
                    }
                }
        }
        return uri.lastPathSegment?.substringAfterLast('/')
    }
}

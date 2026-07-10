package dev.snehit.imagesync.imagesync

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.net.wifi.WifiManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "imagesync/multicast")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> {
                        try {
                            acquireMulticastLock()
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("multicast-lock", error.message, null)
                        }
                    }
                    "release" -> {
                        try {
                            releaseMulticastLock()
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("multicast-lock", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "imagesync/clipboard")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "writeImage" -> {
                        val path = call.argument<String>("path")
                        val mime = call.argument<String>("mime")
                        if (path == null || mime == null) {
                            result.error("bad-args", "path and mime are required", null)
                        } else {
                            try {
                                writeImageToClipboard(File(path), mime)
                                result.success(null)
                            } catch (error: Exception) {
                                result.error("clipboard-write", error.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        releaseMulticastLock()
        multicastLock = null
        super.onDestroy()
    }

    private fun acquireMulticastLock() {
        val lock = multicastLock
            ?: (applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager)
                .createMulticastLock("imagesync-mdns")
                .also {
                    it.setReferenceCounted(false)
                    multicastLock = it
                }
        if (!lock.isHeld) lock.acquire()
    }

    private fun releaseMulticastLock() {
        multicastLock?.takeIf { it.isHeld }?.release()
    }

    private fun writeImageToClipboard(file: File, mime: String) {
        require(file.exists()) { "Image file not found: ${file.path}" }
        // getUriForFile also rejects paths outside the provider's configured
        // imagesync_received/ subtree.
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
        val clip = ClipData(ClipDescription("ImageSync image", arrayOf(mime)), ClipData.Item(uri))
        val manager = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        manager.setPrimaryClip(clip)
    }
}

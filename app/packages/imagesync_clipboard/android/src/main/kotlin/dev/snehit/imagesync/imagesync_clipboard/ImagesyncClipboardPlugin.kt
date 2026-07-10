package dev.snehit.imagesync.imagesync_clipboard

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hosts the `imagesync/clipboard` MethodChannel from application context.
 *
 * As a plugin in GeneratedPluginRegistrant it attaches to every FlutterEngine —
 * the activity engine and the headless foreground-service engine alike — so the
 * service isolate can write the clipboard directly. Nothing here needs an
 * Activity: ClipboardManager, FileProvider.getUriForFile, and setPrimaryClip
 * all work from application context.
 */
class ImagesyncClipboardPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "imagesync/clipboard")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        when (call.method) {
            "writeText" -> {
                val text = call.argument<String>("text")
                if (text == null) {
                    result.error("bad-args", "text is required", null)
                } else {
                    setPrimaryClip(result) { ClipData.newPlainText("ImageSync text", text) }
                }
            }
            "writeImage" -> {
                val path = call.argument<String>("path")
                val mime = call.argument<String>("mime")
                if (path == null || mime == null) {
                    result.error("bad-args", "path and mime are required", null)
                } else {
                    setPrimaryClip(result) { imageClip(File(path), mime) }
                }
            }
            "openClipboardPermissionSettings" -> {
                try {
                    openClipboardPermissionSettings()
                    result.success(null)
                } catch (error: Exception) {
                    result.error("open-settings", error.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    // MIUI's privacy layer rejects background writes with a SecurityException;
    // a distinct error code lets Dart tell "blocked by device policy" apart
    // from an ordinary write failure.
    private inline fun setPrimaryClip(
        result: MethodChannel.Result,
        clip: () -> ClipData
    ) {
        try {
            val manager = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            manager.setPrimaryClip(clip())
            result.success(null)
        } catch (error: SecurityException) {
            result.error("clipboard-blocked", error.message, null)
        } catch (error: Exception) {
            result.error("clipboard-write", error.message, null)
        }
    }

    private fun imageClip(
        file: File,
        mime: String
    ): ClipData {
        require(file.exists()) { "Image file not found: ${file.path}" }
        // getUriForFile also rejects paths outside the provider's configured
        // imagesync_received/ subtree.
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        return ClipData(ClipDescription("ImageSync image", arrayOf(mime)), ClipData.Item(uri))
    }

    // Community-known MIUI permission editor (unverified upstream — keep the
    // fallback); resolves to the standard app-details screen elsewhere.
    private fun openClipboardPermissionSettings() {
        val editor = Intent("miui.intent.action.APP_PERM_EDITOR").apply {
            putExtra("extra_pkgname", context.packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val intent = if (editor.resolveActivity(context.packageManager) != null) {
            editor
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", context.packageName, null)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        }
        context.startActivity(intent)
    }
}

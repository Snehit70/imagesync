package dev.snehit.imagesync.screenshot_observer

import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.provider.MediaStore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CopyOnWriteArraySet

/**
 * Hosts the screenshot observer channels from application context.
 *
 * As a plugin in GeneratedPluginRegistrant it attaches to every FlutterEngine —
 * the activity engine and the headless foreground-service engine alike — so the
 * service isolate can drive a single MediaStore [ContentObserver]. The observing
 * state lives in the process-wide [ScreenshotWatcher] singleton (not this
 * instance), so at most one observer exists no matter how many engines attach.
 */
class ScreenshotObserverPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel =
            MethodChannel(binding.binaryMessenger, "imagesync/screenshot_observer")
        methodChannel.setMethodCallHandler(this)
        eventChannel =
            EventChannel(binding.binaryMessenger, "imagesync/screenshot_events")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        when (call.method) {
            "start" -> {
                val level = ScreenshotWatcher.accessLevel(context)
                if (level != "full") {
                    // The observer is useless without the full grant (§5); refuse
                    // and report the detected level so #30 can drive recovery UX.
                    result.error("no-permission", level, null)
                } else {
                    ScreenshotWatcher.start(context)
                    result.success(null)
                }
            }
            "stop" -> {
                ScreenshotWatcher.stop()
                result.success(null)
            }
            "accessLevel" -> result.success(ScreenshotWatcher.accessLevel(context))
            "readImage" -> {
                val id = call.argument<Number>("id")?.toLong()
                if (id == null) {
                    result.error("bad-args", "id is required", null)
                } else {
                    ScreenshotWatcher.readImage(
                        context,
                        id,
                        onSuccess = { result.success(it) },
                        onError = { code, message -> result.error(code, message, null) },
                    )
                }
            }
            else -> result.notImplemented()
        }
    }

    // Only the service isolate listens (§6); the singleton fans events out to
    // whichever engine sinks are active.
    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        ScreenshotWatcher.addSink(events)
    }

    override fun onCancel(arguments: Any?) {
        // The framework hands no sink to onCancel; the singleton drops sinks whose
        // engine detached the next time it fans out. Nothing to do here.
    }
}

/**
 * Process-wide MediaStore observer. Idempotent [start]; [stop] is a no-op when
 * not watching. All observing runs on a dedicated [HandlerThread]; event
 * delivery hops to the main looper because platform-channel sends must originate
 * there (spec §2).
 */
object ScreenshotWatcher {
    private const val DEBOUNCE_MS = 500L
    private const val WINDOW_SECONDS = 30L
    private const val DEDUP_CAPACITY = 64

    private val mainHandler = Handler(Looper.getMainLooper())
    private val sinks = CopyOnWriteArraySet<EventChannel.EventSink>()

    private var appContext: Context? = null
    private var handlerThread: HandlerThread? = null
    private var bgHandler: Handler? = null
    private var readerHandler: Handler? = null
    private var observer: ContentObserver? = null
    private var startWatermarkSeconds = 0L
    private var debounceRunnable: Runnable? = null

    // Bounded LRU of the last emitted _IDs; the pending→final flip and MIUI's
    // coalesced re-queries dedup cleanly against stable row ids (spec §4.4).
    private val seenIds =
        object : LinkedHashMap<Long, Boolean>(DEDUP_CAPACITY, 0.75f, true) {
            override fun removeEldestEntry(
                eldest: Map.Entry<Long, Boolean>?
            ): Boolean = size > DEDUP_CAPACITY
        }

    fun addSink(sink: EventChannel.EventSink) {
        sinks.add(sink)
    }

    @Synchronized
    fun start(context: Context) {
        if (observer != null) return // idempotent
        val app = context.applicationContext
        appContext = app
        // now() so a service restart never replays a screenshot taken before the
        // service came up; there is no catch-up scan on start (spec §4.3).
        startWatermarkSeconds = System.currentTimeMillis() / 1000
        seenIds.clear()

        val thread = HandlerThread("imagesync-screenshot-observer").apply { start() }
        handlerThread = thread
        val handler = Handler(thread.looper)
        bgHandler = handler

        val obs = object : ContentObserver(handler) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                onObserverChange(uri)
            }
        }
        observer = obs
        app.contentResolver.registerContentObserver(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            /* notifyForDescendants = */ true,
            obs,
        )
    }

    @Synchronized
    fun stop() {
        observer?.let { appContext?.contentResolver?.unregisterContentObserver(it) }
        observer = null
        debounceRunnable?.let { bgHandler?.removeCallbacks(it) }
        debounceRunnable = null
        handlerThread?.quitSafely()
        handlerThread = null
        bgHandler = null
        seenIds.clear()
    }

    private fun onObserverChange(uri: Uri?) {
        emitLog("screenshot onChange" + (uri?.let { " uri=$it" } ?: ""))
        val handler = bgHandler ?: return
        // Debounce: a burst of notifications (pending insert, IS_PENDING flip,
        // MIUI coalescing) collapses into a single query (spec §4.1).
        debounceRunnable?.let { handler.removeCallbacks(it) }
        val runnable = Runnable { runQuery() }
        debounceRunnable = runnable
        handler.postDelayed(runnable, DEBOUNCE_MS)
    }

    private fun runQuery() {
        val context = appContext ?: return
        val windowStart = (System.currentTimeMillis() / 1000) - WINDOW_SECONDS
        val projection = arrayOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.BUCKET_DISPLAY_NAME,
            MediaStore.Images.Media.RELATIVE_PATH,
            MediaStore.Images.Media.MIME_TYPE,
            MediaStore.Images.Media.SIZE,
            MediaStore.Images.Media.DATE_ADDED,
        )
        val selection = "${MediaStore.Images.Media.DATE_ADDED} >= ?"
        val selectionArgs = arrayOf(windowStart.toString())
        val sortOrder = "${MediaStore.Images.Media.DATE_ADDED} DESC"

        var rowsInWindow = 0
        val fresh = ArrayList<ScreenshotRow>()
        context.contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            sortOrder,
        )?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
            val nameCol =
                cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DISPLAY_NAME)
            val bucketCol =
                cursor.getColumnIndexOrThrow(MediaStore.Images.Media.BUCKET_DISPLAY_NAME)
            val pathCol =
                cursor.getColumnIndexOrThrow(MediaStore.Images.Media.RELATIVE_PATH)
            val mimeCol =
                cursor.getColumnIndexOrThrow(MediaStore.Images.Media.MIME_TYPE)
            val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.SIZE)
            val dateCol =
                cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_ADDED)

            while (cursor.moveToNext()) {
                rowsInWindow++
                val id = cursor.getLong(idCol)
                val displayName = cursor.getString(nameCol) ?: ""
                val bucket = cursor.getString(bucketCol) ?: ""
                val mime = cursor.getString(mimeCol) ?: ""
                val size = cursor.getLong(sizeCol)
                val dateAdded = cursor.getLong(dateCol)

                if (dateAdded < startWatermarkSeconds) continue
                if (seenIds.containsKey(id)) continue
                if (!isScreenshot(bucket, displayName)) continue

                seenIds[id] = true
                fresh.add(ScreenshotRow(id, displayName, mime, size, dateAdded))
            }
        }

        emitLog(
            "screenshot query: windowStart=$windowStart " +
                "rowsInWindow=$rowsInWindow surviving=${fresh.size}",
        )
        for (row in fresh) emitScreenshot(row)
    }

    // AOSP Pictures/Screenshots and MIUI/HyperOS DCIM/Screenshots both leave the
    // bucket name "Screenshots"; the display-name fallback catches skins that
    // localize the folder but keep Screenshot_*.png naming (spec §4a).
    private fun isScreenshot(bucket: String, displayName: String): Boolean {
        if (bucket.equals("Screenshots", ignoreCase = true)) return true
        return displayName.contains("screenshot", ignoreCase = true)
    }

    private fun emitScreenshot(row: ScreenshotRow) {
        val uri = ContentUris.withAppendedId(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            row.id,
        ).toString()
        val payload = mapOf(
            "type" to "screenshot",
            "id" to row.id,
            "uri" to uri,
            "displayName" to row.displayName,
            "mimeType" to row.mimeType,
            "sizeBytes" to row.sizeBytes,
            "dateAddedEpochSeconds" to row.dateAddedEpochSeconds,
            "detectedAtEpochMillis" to System.currentTimeMillis(),
        )
        fanOut(payload)
    }

    private fun emitLog(message: String) {
        fanOut(mapOf("type" to "log", "message" to message))
    }

    private fun fanOut(payload: Map<String, Any?>) {
        if (sinks.isEmpty()) return
        mainHandler.post {
            for (sink in sinks) {
                try {
                    sink.success(payload)
                } catch (_: Exception) {
                    // A sink whose engine detached throws; drop it so it can't
                    // wedge future fan-outs.
                    sinks.remove(sink)
                }
            }
        }
    }

    /**
     * Reads a MediaStore image row's bytes off the platform thread (spec §2).
     * Runs on the observer's [HandlerThread] when watching; otherwise on a
     * lazily created reader thread, so the share-less readImage path (retries
     * after a stop, tests) still never blocks the main looper. Dart owns the
     * retry policy; this is a single attempt.
     */
    fun readImage(
        context: Context,
        id: Long,
        onSuccess: (ByteArray) -> Unit,
        onError: (code: String, message: String?) -> Unit,
    ) {
        val app = context.applicationContext
        readHandler().post {
            try {
                val uri = ContentUris.withAppendedId(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    id,
                )
                val stream = app.contentResolver.openInputStream(uri)
                if (stream == null) {
                    mainHandler.post { onError("not-found", "No stream for $uri") }
                } else {
                    val bytes = stream.use { it.readBytes() }
                    mainHandler.post { onSuccess(bytes) }
                }
            } catch (e: java.io.FileNotFoundException) {
                mainHandler.post { onError("not-found", e.message) }
            } catch (e: Exception) {
                // IOException, SecurityException, dead row: all read failures
                // Dart may retry once MediaStore settles.
                mainHandler.post { onError("io-error", e.message) }
            }
        }
    }

    @Synchronized
    private fun readHandler(): Handler {
        bgHandler?.let { return it }
        val existing = readerHandler
        if (existing != null) return existing
        val thread = HandlerThread("imagesync-screenshot-reader").apply { start() }
        return Handler(thread.looper).also { readerHandler = it }
    }

    fun accessLevel(context: Context): String {
        val app = context.applicationContext
        return when {
            Build.VERSION.SDK_INT >= 33 -> when {
                granted(app, "android.permission.READ_MEDIA_IMAGES") -> "full"
                // The system grants VISUAL_USER_SELECTED on "Select photos" even
                // though we never declare it — the partial-grant tell (§5).
                Build.VERSION.SDK_INT >= 34 &&
                    granted(app, "android.permission.READ_MEDIA_VISUAL_USER_SELECTED") ->
                    "partial"
                else -> "denied"
            }
            else ->
                if (granted(app, "android.permission.READ_EXTERNAL_STORAGE")) "full"
                else "denied"
        }
    }

    private fun granted(context: Context, permission: String): Boolean {
        return context.checkSelfPermission(permission) ==
            PackageManager.PERMISSION_GRANTED
    }

    private data class ScreenshotRow(
        val id: Long,
        val displayName: String,
        val mimeType: String,
        val sizeBytes: Long,
        val dateAddedEpochSeconds: Long,
    )
}

package dev.snehit.vidyut.vidyut

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vidyut/multicast")
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
    }

    override fun onDestroy() {
        releaseMulticastLock()
        multicastLock = null
        super.onDestroy()
    }

    private fun acquireMulticastLock() {
        val lock = multicastLock
            ?: (applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager)
                .createMulticastLock("vidyut-mdns")
                .also {
                    it.setReferenceCounted(false)
                    multicastLock = it
                }
        if (!lock.isHeld) lock.acquire()
    }

    private fun releaseMulticastLock() {
        multicastLock?.takeIf { it.isHeld }?.release()
    }
}

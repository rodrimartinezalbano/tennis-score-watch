package com.rodrigo.tennis_score_poc

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import com.rodrigo.tennis_score_poc.watch.WatchBridge
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var events: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WatchBridge.init(this)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "tennis/watch").setMethodCallHandler { call, result ->
            when (call.method) {
                "getState" -> result.success(
                    mapOf(
                        "mac" to WatchBridge.savedMac,
                        "hasKey" to WatchBridge.hasSavedKey,
                        "status" to WatchBridge.status.name,
                    ),
                )
                "saveCredentials" -> {
                    WatchBridge.saveCredentials(
                        call.argument<String>("mac") ?: "",
                        call.argument<String>("key"),
                    )
                    result.success(null)
                }
                "connect" -> {
                    if (hasBluetoothPermission()) WatchBridge.connect() else requestBluetoothPermission()
                    result.success(null)
                }
                "disconnect" -> {
                    WatchBridge.disconnect()
                    result.success(null)
                }
                "setScore" -> {
                    WatchBridge.setScore(
                        call.argument<String>("title") ?: "",
                        call.argument<String>("artist") ?: "",
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "tennis/watch/events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                events = sink
                sink.success(mapOf("type" to "status", "status" to WatchBridge.status.name))
            }

            override fun onCancel(arguments: Any?) {
                events = null
            }
        })

        WatchBridge.listener = object : WatchBridge.Listener {
            override fun onStatus(status: WatchBridge.Status, detail: String?) {
                events?.success(mapOf("type" to "status", "status" to status.name, "detail" to detail))
            }

            override fun onButton(button: WatchBridge.Button) {
                events?.success(mapOf("type" to "button", "button" to button.name))
            }

            override fun onHeartRate(bpm: Int) {
                events?.success(mapOf("type" to "heartRate", "bpm" to bpm))
            }
        }
    }

    private fun hasBluetoothPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    private fun requestBluetoothPermission() {
        requestPermissions(arrayOf(Manifest.permission.BLUETOOTH_CONNECT), REQUEST_BLUETOOTH)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_BLUETOOTH && grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            WatchBridge.connect()
        }
    }

    private companion object {
        const val REQUEST_BLUETOOTH = 1
    }
}

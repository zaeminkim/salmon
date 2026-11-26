package com.example.salmon

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private var headingStream: DeviceHeadingStream? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val stream = DeviceHeadingStream(this)
        headingStream = stream
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "salmon/device_heading")
            .setStreamHandler(stream)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        headingStream?.onCancel(null)
        headingStream = null
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "salmon/device_heading")
            .setStreamHandler(null)
        super.cleanUpFlutterEngine(flutterEngine)
    }
}

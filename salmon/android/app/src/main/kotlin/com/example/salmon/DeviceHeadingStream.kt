package com.example.salmon

import android.app.Activity
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.view.Surface
import io.flutter.plugin.common.EventChannel
import kotlin.math.abs

internal class DeviceHeadingStream(private val activity: Activity) :
    EventChannel.StreamHandler, SensorEventListener {
    private val sensors = activity.getSystemService(SensorManager::class.java)
    private val rotationMatrix = FloatArray(9)
    private val screenMatrix = FloatArray(9)
    private val orientation = FloatArray(3)
    private var sink: EventChannel.EventSink? = null
    private var declination = 0.0
    private var lastHeading: Double? = null
    private var lastSample = 0L

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        onCancel(null)
        sink = events
        events.success(null)

        val position = arguments as? Map<*, *> ?: return
        val latitude = (position["latitude"] as? Number)?.toFloat() ?: return
        val longitude = (position["longitude"] as? Number)?.toFloat() ?: return
        val altitude = (position["altitude"] as? Number)?.toFloat() ?: 0f
        declination = GeomagneticField(
            latitude, longitude, altitude, System.currentTimeMillis()
        ).declination.toDouble()

        val sensor = sensors?.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
            ?: sensors?.getDefaultSensor(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR)
            ?: return
        sensors?.registerListener(this, sensor, SensorManager.SENSOR_DELAY_UI)
    }

    override fun onCancel(arguments: Any?) {
        sensors?.unregisterListener(this)
        sink = null
        lastHeading = null
        lastSample = 0
    }

    @Suppress("DEPRECATION")
    override fun onSensorChanged(event: SensorEvent) {
        if (event.accuracy == SensorManager.SENSOR_STATUS_UNRELIABLE) {
            if (lastHeading != null) sink?.success(null)
            lastHeading = null
            return
        }
        if (event.timestamp - lastSample < 80_000_000L) return
        lastSample = event.timestamp

        SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
        val (x, y) = when (activity.windowManager.defaultDisplay.rotation) {
            Surface.ROTATION_90 -> SensorManager.AXIS_Y to SensorManager.AXIS_MINUS_X
            Surface.ROTATION_180 -> SensorManager.AXIS_MINUS_X to SensorManager.AXIS_MINUS_Y
            Surface.ROTATION_270 -> SensorManager.AXIS_MINUS_Y to SensorManager.AXIS_X
            else -> SensorManager.AXIS_X to SensorManager.AXIS_Y
        }
        SensorManager.remapCoordinateSystem(rotationMatrix, x, y, screenMatrix)
        SensorManager.getOrientation(screenMatrix, orientation)
        val heading = (Math.toDegrees(orientation[0].toDouble()) + declination + 360) % 360
        val previous = lastHeading
        if (previous != null && abs((heading - previous + 540) % 360 - 180) < 2) return
        lastHeading = heading
        sink?.success(heading)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
}

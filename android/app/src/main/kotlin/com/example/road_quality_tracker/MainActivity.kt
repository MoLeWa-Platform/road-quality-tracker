package com.example.road_quality_tracker

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "rotation_vector_channel"
    private var sensorManager: SensorManager? = null
    private var rotationVectorSensor: Sensor? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        rotationVectorSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                private val sensorListener = object : SensorEventListener {
                    override fun onSensorChanged(event: SensorEvent?) {
                        event?.let {
                            val floatValues = it.values
                            val doubleValues = floatValues.map { v -> v.toDouble() }
                            eventSink?.success(doubleValues)
                        }
                    }

                    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
                }

                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                    sensorManager?.registerListener(sensorListener, rotationVectorSensor, SensorManager.SENSOR_DELAY_GAME)
                }

                override fun onCancel(arguments: Any?) {
                    sensorManager?.unregisterListener(sensorListener)
                    eventSink = null
                }
            }
        )
    }
}

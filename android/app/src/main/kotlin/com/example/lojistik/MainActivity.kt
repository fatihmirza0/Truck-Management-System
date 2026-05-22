package com.example.lojistik

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "location_service"
    private val EVENT_CHANNEL  = LocationForegroundService.EVENT_CHANNEL

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ----------------------------------------------------------------
        // 1. EventChannel – Kotlin → Dart konum akışı
        // ----------------------------------------------------------------
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    LocationForegroundService.eventSink = events
                    println("✅ EventChannel: Dart listening for location events")
                }

                override fun onCancel(arguments: Any?) {
                    LocationForegroundService.eventSink = null
                    println("⚠️ EventChannel: Dart stopped listening")
                }
            })

        // ----------------------------------------------------------------
        // 2. MethodChannel – Dart → Kotlin komutları (servis başlat/durdur)
        // ----------------------------------------------------------------
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                // Şoför ID'sini SharedPreferences'a kaydet (arka plan servisinin kullanması için)
                "saveDriverId" -> {
                    val driverId = call.argument<String>("driverId")
                    getSharedPreferences("app", MODE_PRIVATE)
                        .edit()
                        .putString("driverId", driverId)
                        .apply()
                    println("✅ Native: Driver ID saved: $driverId")
                    result.success(null)
                }

                // Foreground GPS servisini başlat
                "startService" -> {
                    val intent = Intent(this, LocationForegroundService::class.java)
                    startForegroundService(intent)
                    println("✅ Native: LocationForegroundService started")
                    result.success(null)
                }

                // Servisi durdur ve SharedPreferences'ı temizle
                "stopService" -> {
                    val intent = Intent(this, LocationForegroundService::class.java)
                    stopService(intent)
                    getSharedPreferences("app", MODE_PRIVATE)
                        .edit()
                        .remove("driverId")
                        .apply()
                    println("✅ Native: LocationForegroundService stopped")
                    result.success(null)
                }

                // Tam çıkış: servis durdur + tüm prefs temizle
                "logout" -> {
                    val intent = Intent(this, LocationForegroundService::class.java)
                    stopService(intent)
                    getSharedPreferences("app", MODE_PRIVATE)
                        .edit()
                        .clear()
                        .apply()
                    println("🔓 Native: Logout completed")
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }
}
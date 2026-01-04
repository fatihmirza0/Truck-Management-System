package com.example.lojistik

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "location_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {
                // 🔥 Driver ID kaydet
                "saveDriverId" -> {
                    val driverId = call.argument<String>("driverId")
                    getSharedPreferences("app", MODE_PRIVATE)
                        .edit()
                        .putString("driverId", driverId)
                        .apply()
                    println("✅ Native: Driver ID saved: $driverId")
                    result.success(null)
                }

                // 🔥 YENİ: Service başlat
                "startService" -> {
                    val intent = Intent(this, LocationForegroundService::class.java)
                    startForegroundService(intent)
                    println("✅ Native: Service started")
                    result.success(null)
                }

                // 🔥 YENİ: Service durdur + temizle
                "stopService" -> {
                    val intent = Intent(this, LocationForegroundService::class.java)
                    stopService(intent)

                    // SharedPreferences temizle
                    getSharedPreferences("app", MODE_PRIVATE)
                        .edit()
                        .remove("driverId")
                        .apply()

                    println("✅ Native: Service stopped & cleared")
                    result.success(null)
                }

                // 🔥 YENİ: Logout (tam temizlik)
                "logout" -> {
                    // Service'i durdur
                    val intent = Intent(this, LocationForegroundService::class.java)
                    stopService(intent)

                    // SharedPreferences'ı tamamen temizle
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
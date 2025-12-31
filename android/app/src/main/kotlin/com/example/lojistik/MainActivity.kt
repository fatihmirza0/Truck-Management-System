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
            "location_service"
        ).setMethodCallHandler { call, result ->

            when (call.method) {
                // 🔥 YENİ: Driver ID kaydet
                "saveDriverId" -> {
                    val driverId = call.argument<String>("driverId")
                    getSharedPreferences("app", MODE_PRIVATE)
                        .edit()
                        .putString("driverId", driverId)
                        .apply()
                    result.success(null)
                }

                "startService" -> {
                    val intent = Intent(this, LocationForegroundService::class.java)
                    startForegroundService(intent)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }}

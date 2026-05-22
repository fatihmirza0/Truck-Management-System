package com.example.lojistik

import android.app.*
import android.content.Intent
import android.os.*
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

/**
 * LocationForegroundService - "Dumb" GPS Service
 *
 * Bu servis ARTIK Firebase'e doğrudan yazmıyor.
 * Görevi tek: GPS konumunu okuyup EventChannel üzerinden Dart'a iletmek.
 * Dart tarafındaki DriverLocationService.dart tüm zekâyı (idle/active throttle,
 * RTDB yazma, pil optimizasyonu) yönetir.
 */
class LocationForegroundService : Service() {

    private lateinit var fusedClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback

    companion object {
        const val EVENT_CHANNEL = "location_service/stream"

        // Singleton EventSink - MainActivity tarafından set edilir
        var eventSink: EventChannel.EventSink? = null
    }

    override fun onCreate() {
        super.onCreate()
        fusedClient = LocationServices.getFusedLocationProviderClient(this)
        startForegroundNotification()
        startLocationUpdates()
    }

    private fun startForegroundNotification() {
        val channelId = "location_service"

        val channel = NotificationChannel(
            channelId,
            "Konum Servisi",
            NotificationManager.IMPORTANCE_LOW
        )

        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Konum Takibi Aktif")
            .setContentText("Sürücü konumu paylaşılıyor")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .build()

        startForeground(1, notification)
    }

    private fun startLocationUpdates() {
        val request = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            5_000L  // 5sn'de bir GPS oku (Dart tarafı throttle eder, bu sadece ham veri)
        )
            .setMinUpdateIntervalMillis(3_000L)
            .build()

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                val loc = result.lastLocation ?: return

                // Konum verisini Map olarak EventChannel'dan Dart'a ilet
                val locationData = mapOf(
                    "lat"      to loc.latitude,
                    "lng"      to loc.longitude,
                    "accuracy" to loc.accuracy.toDouble(),
                    "speed"    to loc.speed.toDouble(),          // m/s
                    "heading"  to loc.bearing.toDouble(),
                    "time"     to loc.time                       // epoch ms
                )

                // Ana thread'de gönder (EventChannel UI thread gerektirir)
                Handler(Looper.getMainLooper()).post {
                    eventSink?.success(locationData)
                }
            }
        }

        try {
            fusedClient.requestLocationUpdates(
                request,
                locationCallback,
                Looper.getMainLooper()
            )
        } catch (e: SecurityException) {
            // İzin verilmemişse sessizce bitir; Dart tarafı permission_handler ile yönetir
            stopSelf()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        fusedClient.removeLocationUpdates(locationCallback)
        eventSink = null
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

package com.example.lojistik

import android.app.*
import android.content.Intent
import android.os.*
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import com.google.firebase.database.FirebaseDatabase

class LocationForegroundService : Service() {

    private lateinit var fusedClient: FusedLocationProviderClient
    private val db = FirebaseDatabase.getInstance().reference

    override fun onCreate() {
        super.onCreate()
        fusedClient = LocationServices.getFusedLocationProviderClient(this)
        startForegroundService()
        startLocationUpdates()
    }

    private fun startForegroundService() {
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
            10_000
        ).build()

        fusedClient.requestLocationUpdates(
            request,
            object : LocationCallback() {
                override fun onLocationResult(result: LocationResult) {
                    val loc = result.lastLocation ?: return

                    val driverId = getSharedPreferences("app", MODE_PRIVATE)
                        .getString("driverId", null) ?: return

                    db.child("locations/$driverId").updateChildren(
                        mapOf(
                            "lat" to loc.latitude,
                            "lng" to loc.longitude,
                            "lastPing" to System.currentTimeMillis(),
                            "isOnline" to true
                        )
                    )
                }
            },
            Looper.getMainLooper()
        )
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

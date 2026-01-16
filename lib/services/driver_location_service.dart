import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

class DriverLocationService {
  final String driverId;

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _channel = MethodChannel('location_service');

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<DocumentSnapshot>? _jobSub;
  Timer? _updateTimer;
  Timer? _permissionCheckTimer;
  Timer? _historyCleanupTimer;

  Position? _lastPosition;
  LatLng? _lastSentPosition;
  DateTime? _lastMoveTime;

  bool _isTracking = false;
  bool _isUpdating = false; // 🔥 Lock mekanizması
  bool _isMoving = false;
  bool _isIdle = false; // 🔥 YENİ: Idle state tracking

  String _jobStatus = 'available';
  String? _companyId; // 🔥 Backend optimize için
  String? _fcmToken; // 🔥 Backend optimize için
  String? _activePlate; // 🔥 Redundancy

  final List<Position> _buffer = [];

  // ======================================================
  // CONFIGURATION
  // ======================================================
  static const int _activeInterval = 10; // Hareket halinde
  static const int _passiveInterval = 60; // Dururken (Pil tasarrufu)
  
  static const int _idleTimeout = 300;
  static const int _bufferSize = 6;
  static const double _minMoveDistance = 10;
  static const double _minAccuracy = 25;

  static const double _historyMinDistance = 25.0;
  static const int _historyRetentionHours = 24;
  static const int _historyMaxPoints = 500;
  static const int _historyCleanupIntervalHours = 24;
  
  int _currentInterval = _activeInterval;

  DriverLocationService(this.driverId);

  bool get isTracking => _isTracking;

  // ======================================================
  // START - 🔥 İYİLEŞTİRİLDİ
  // ======================================================
  Future<void> startTracking() async {
    if (_isTracking) return;
    _isTracking = true;
    _isIdle = false;

    try {
      await _channel.invokeMethod('saveDriverId', {'driverId': driverId});
      debugPrint("✅ Driver ID saved to native: $driverId");
    } catch (e) {
      debugPrint("⚠️ Could not save driver ID to native: $e");
    }

    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permission denied");
    }

    await _initLocation();
    await _listenJobStatus(); // 🔥 Verileri al: companyId, plate, token
    
    // Kısa bir gecikme ile users datasının gelmesini bekle (opsiyonel ama iyi olur)
    await Future.delayed(const Duration(milliseconds: 500));
    
    await _setOnline();

    // 🔥 onDisconnect her zaman güncelle
    await _setupDisconnectHandler();

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(
      _onLocation,
      onError: (error) {
        debugPrint("❌ Position stream error: $error");
      },
      cancelOnError: false,
    );
    
    _startUpdateTimer(_activeInterval); // Başlangıçta aktif mod

    _permissionCheckTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkLocationPermission(),
    );

    _historyCleanupTimer = Timer.periodic(
      const Duration(hours: _historyCleanupIntervalHours),
      (_) => _cleanupOldHistory(),
    );

    _cleanupOldHistory();

    debugPrint("✅ Tracking started");
  }
  
  void _startUpdateTimer(int intervalSeconds) {
    _updateTimer?.cancel();
    _currentInterval = intervalSeconds;
    _updateTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => _updateToRTDB(),
    );
    debugPrint("⏱️ Update interval set to ${intervalSeconds}s");
  }

  // 🔥 YENİ: onDisconnect handler'ı ayarla
  Future<void> _setupDisconnectHandler() async {
    try {
      await _db.child("locations/$driverId").onDisconnect().update({
        "isOnline": false,
        "lastPing": ServerValue.timestamp,
      });
      debugPrint("✅ Disconnect handler set");
    } catch (e) {
      debugPrint("⚠️ Could not set disconnect handler: $e");
    }
  }

  Future<void> _checkLocationPermission() async {
    if (!_isTracking) return;

    final status = await Permission.location.status;

    if (!status.isGranted) {
      debugPrint("⚠️ Location permission revoked by user");

      await _db.child("locations/$driverId").update({
        "isOnline": false,
        "timestamp": ServerValue.timestamp,
        "lastPing": ServerValue.timestamp,
        "permissionRevoked": true,
      });

      await stopTracking();
    }
  }

  // ======================================================
  // STOP - 🔥 İYİLEŞTİRİLDİ
  // ======================================================
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    _isTracking = false;

    // 🔥 Stream'leri önce iptal et
    await _positionSub?.cancel();
    await _jobSub?.cancel();

    // 🔥 Timer'ları iptal et
    _updateTimer?.cancel();
    _permissionCheckTimer?.cancel();
    _historyCleanupTimer?.cancel();

    // 🔥 Buffer'ı temizle
    _buffer.clear();
    _lastPosition = null;
    _lastSentPosition = null;
    _lastMoveTime = null;
    _isMoving = false;
    _isIdle = false;

    await _setOffline();

    // 🔥 Referansları null'la
    _positionSub = null;
    _jobSub = null;
    _updateTimer = null;
    _permissionCheckTimer = null;
    _historyCleanupTimer = null;

    debugPrint("🛑 Tracking stopped");
  }

  // ======================================================
  // INIT
  // ======================================================
  Future<void> _initLocation() async {
    _lastPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _listenJobStatus() async {
    _jobSub = _firestore.collection('users').doc(driverId).snapshots().listen(
      (doc) {
        if (!_isTracking) return; // 🔥 Tracking yoksa işleme

        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
             final newStatus = data['jobStatus'] ?? 'available';
             
             // 🔥 Critical Data for Backend Optimization
             _companyId = data['companyId'];
             _fcmToken = data['fcmToken'];
             _activePlate = data['activePlate'];
             
             if (_jobStatus != newStatus) {
               _jobStatus = newStatus;
               debugPrint("🔄 Job status changed: $_jobStatus");

               // 🔥 Job status değişince idle durumunu resetle
               if (_jobStatus == 'busy') {
                 _isIdle = false;
                 // Busy modda sık güncelle
                 if (_currentInterval != _activeInterval) {
                    _startUpdateTimer(_activeInterval);
                 }
               }

               _updateToRTDB();
             }
          }
        }
      },
      onError: (error) {
        debugPrint("❌ Job status stream error: $error");
      },
      cancelOnError: false,
    );
  }

  // ======================================================
  // LOCATION HANDLING - 🔥 İYİLEŞTİRİLDİ
  // ======================================================
  void _onLocation(Position pos) {
    if (!_isTracking) return; // 🔥 Tracking yoksa işleme
    if (pos.accuracy > _minAccuracy) return;

    _lastPosition = pos;
    _buffer.add(pos);

    if (_buffer.length > _bufferSize) {
      _buffer.removeAt(0);
    }

    _calculateMovement();
  }

  void _calculateMovement() {
    if (_buffer.length < 3) return;

    // Accuracy kontrolü artık _onLocation'da
    final goodPoints = _buffer.toList();
    if (goodPoints.length < 3) return;

    double totalDistance = 0;
    int totalTime = 0;
    final List<double> speeds = [];

    for (int i = 1; i < goodPoints.length; i++) {
      final a = goodPoints[i - 1];
      final b = goodPoints[i];

      final segmentDistance = Geolocator.distanceBetween(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      );

      final segmentTime = b.timestamp.difference(a.timestamp).inSeconds;

      if (segmentTime < 2) continue;

      totalDistance += segmentDistance;
      totalTime += segmentTime;

      final segmentSpeed = (segmentDistance / segmentTime) * 3.6;

      if (segmentSpeed <= 150) {
        speeds.add(segmentSpeed);
      }
    }

    if (totalTime < 5 || speeds.isEmpty) {
      _isMoving = false;
      return;
    }

    final avgSpeed = speeds.reduce((a, b) => a + b) / speeds.length;
    bool wasMoving = _isMoving;
    _isMoving = totalDistance >= 20 && avgSpeed >= 8;

    if (_isMoving) {
      _lastMoveTime = DateTime.now();
      _isIdle = false; // 🔥 Hareket varsa idle değil
    }
    
    // 🔥 DYNAMIC INTERVAL SWITCH
    // Hareket varsa veya meşgulse -> AKTİF MOD (10s)
    // Hareket yoksa ve boşsa -> PASİF MOD (60s)
    if (_isMoving != wasMoving) {
       if (_isMoving || _jobStatus == 'busy') {
         if (_currentInterval != _activeInterval) _startUpdateTimer(_activeInterval);
       } else {
         if (_currentInterval != _passiveInterval) _startUpdateTimer(_passiveInterval);
       }
    }

    debugPrint("🚗 Movement: dist=${totalDistance.toStringAsFixed(1)}m, "
        "speed=${avgSpeed.toStringAsFixed(1)}km/h, moving=$_isMoving, interval=${_currentInterval}s");
  }

  // ======================================================
  // RTDB UPDATE - 🔥 İYİLEŞTİRİLDİ
  // ======================================================
  Future<void> _updateToRTDB() async {
    if (!_isTracking) return; // 🔥 Tracking yoksa çıkış
    if (_lastPosition == null) return;

    // 🔥 Update lock - race condition önleme
    if (_isUpdating) {
      debugPrint("⏳ Update already in progress, skipping...");
      return;
    }

    _isUpdating = true;

    try {
      final now = DateTime.now();

      // 🔥 İyileştirilmiş idle logic
      if (_jobStatus == 'available' &&
          !_isMoving &&
          _lastMoveTime != null &&
          now.difference(_lastMoveTime!).inSeconds > _idleTimeout &&
          !_isIdle) {
        _isIdle = true;
        await _setOffline();
        debugPrint("😴 Driver went idle, set offline");
        return;
      }

      // 🔥 Idle durumda ve hala hareket yoksa güncelleme yapma
      if (_isIdle && !_isMoving && _jobStatus == 'available') {
        return;
      }

      // 🔥 İdle'dan çıkış
      if (_isIdle && _isMoving) {
        _isIdle = false;
        await _setOnline();
        debugPrint("🚗 Driver active again, set online");
      }

      bool shouldAddToHistory = false;
      if (_lastSentPosition != null) {
        final d = Geolocator.distanceBetween(
          _lastSentPosition!.latitude,
          _lastSentPosition!.longitude,
          _lastPosition!.latitude,
          _lastPosition!.longitude,
        );

        shouldAddToHistory = d >= _historyMinDistance;

        if (_jobStatus != 'busy' && d < _minMoveDistance && !_isMoving) return;
      } else {
        shouldAddToHistory = true;
      }

      final data = {
        "lat": _lastPosition!.latitude,
        "lng": _lastPosition!.longitude,
        "heading": _lastPosition!.heading.isNaN ? 0 : _lastPosition!.heading,
        "speed": _isMoving ? _calcSpeed() : 0,
        "accuracy": _lastPosition!.accuracy,
        "isMoving": _isMoving,
        "isOnline": true,
        "timestamp": ServerValue.timestamp,
        "lastPing": ServerValue.timestamp,
        
        // 🔥 Backend Optimizations
        if (_companyId != null) "companyId": _companyId,
        if (_fcmToken != null) "fcmToken": _fcmToken,
        if (_activePlate != null) "activePlate": _activePlate,

        if (_isMoving || _jobStatus == 'busy') "offlineNotified": false,
      };

      await _db.child("locations/$driverId").update(data);

      if (shouldAddToHistory) {
        // 🔥 History ekleme başarısız olsa bile devam et
        unawaited(_addToHistory(data));
        debugPrint("📍 Added to history (${_historyMinDistance}m threshold)");
      }

      _lastSentPosition =
          LatLng(_lastPosition!.latitude, _lastPosition!.longitude);

      debugPrint(
          "📍 Location updated: online (moving: $_isMoving, job: $_jobStatus, int: $_currentInterval)");
    } catch (e) {
      debugPrint("❌ RTDB update error: $e");
    } finally {
      _isUpdating = false;
    }
  }

  double _calcSpeed() {
    if (_buffer.length < 3) return 0;

    final goodPoints = _buffer.toList();
    if (goodPoints.length < 3) return 0;

    double totalDist = 0;
    int totalTime = 0;
    final List<double> speeds = [];

    for (int i = 1; i < goodPoints.length; i++) {
      final a = goodPoints[i - 1];
      final b = goodPoints[i];

      final segmentDist = Geolocator.distanceBetween(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      );

      final segmentTime = b.timestamp.difference(a.timestamp).inSeconds;

      if (segmentTime < 2) continue;

      totalDist += segmentDist;
      totalTime += segmentTime;

      final segmentSpeed = (segmentDist / segmentTime) * 3.6;

      if (segmentSpeed <= 150) {
        speeds.add(segmentSpeed);
      }
    }

    if (totalTime < 3 || speeds.isEmpty) return 0;

    final avgSpeed = speeds.reduce((a, b) => a + b) / speeds.length;
    return avgSpeed < 3 ? 0 : avgSpeed;
  }

  // ======================================================
  // HISTORY MANAGEMENT - 🔥 İYİLEŞTİRİLDİ
  // ======================================================

  Future<void> _addToHistory(Map data) async {
    if (!_isTracking) return;

    try {
      await _db.child("history/$driverId").push().set({
        "lat": data['lat'],
        "lng": data['lng'],
        "timestamp": ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint("⚠️ History add error: $e");
      // Hata olsa bile devam et
    }
  }

  Future<void> _cleanupOldHistory() async {
    if (!_isTracking) return;

    try {
      debugPrint("🧹 Starting history cleanup for driver: $driverId");

      final historyRef = _db.child("history/$driverId");
      final snapshot = await historyRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        debugPrint("✅ No history to clean");
        return;
      }

      final historyData = snapshot.value as Map<dynamic, dynamic>;
      final now = DateTime.now();
      final cutoffTime = now.subtract(Duration(hours: _historyRetentionHours));

      final List<MapEntry<String, int>> entries = [];

      historyData.forEach((key, value) {
        if (value is Map && value['timestamp'] != null) {
          try {
            final timestamp = value['timestamp'] as int;
            entries.add(MapEntry(key.toString(), timestamp));
          } catch (e) {
            debugPrint("⚠️ Invalid timestamp for key $key");
          }
        }
      });

      if (entries.isEmpty) {
        debugPrint("✅ No valid history entries");
        return;
      }

      entries.sort((a, b) => a.value.compareTo(b.value));

      final List<String> keysToDelete = [];

      for (final entry in entries) {
        final entryTime = DateTime.fromMillisecondsSinceEpoch(entry.value);
        if (entryTime.isBefore(cutoffTime)) {
          keysToDelete.add(entry.key);
        }
      }

      final remainingCount = entries.length - keysToDelete.length;
      if (remainingCount > _historyMaxPoints) {
        final excessCount = remainingCount - _historyMaxPoints;

        final notMarkedForDeletion =
            entries.where((e) => !keysToDelete.contains(e.key)).toList();

        for (int i = 0;
            i < excessCount && i < notMarkedForDeletion.length;
            i++) {
          keysToDelete.add(notMarkedForDeletion[i].key);
        }
      }

      if (keysToDelete.isEmpty) {
        debugPrint("✅ No history to delete (${entries.length} points)");
        return;
      }

      // 🔥 Batch silme - hata olursa devam et
      final updates = <String, dynamic>{};
      for (final key in keysToDelete) {
        updates[key] = null;
      }

      try {
        await historyRef.update(updates);
        final remainingPoints = entries.length - keysToDelete.length;
        debugPrint("🧹 Cleaned ${keysToDelete.length} old history points. "
            "Remaining: $remainingPoints (max: $_historyMaxPoints, "
            "retention: ${_historyRetentionHours}h)");
      } catch (e) {
        debugPrint("⚠️ Batch delete failed, trying individual deletes: $e");

        // 🔥 Fallback: Tek tek sil
        int deleted = 0;
        for (final key in keysToDelete) {
          try {
            await historyRef.child(key).remove();
            deleted++;
          } catch (e) {
            debugPrint("⚠️ Could not delete key $key: $e");
          }
        }
        debugPrint(
            "🧹 Deleted $deleted of ${keysToDelete.length} points individually");
      }
    } catch (e) {
      debugPrint("❌ History cleanup error: $e");
    }
  }

  Future<void> clearAllHistory() async {
    try {
      await _db.child("history/$driverId").remove();
      debugPrint("🗑️ All history cleared for driver: $driverId");
    } catch (e) {
      debugPrint("❌ Clear history error: $e");
    }
  }

  // ======================================================
  // STATUS
  // ======================================================
  Future<void> _setOnline() async {
    if (_lastPosition == null) return;

    try {
      final data = {
        "lat": _lastPosition!.latitude,
        "lng": _lastPosition!.longitude,
        "isOnline": true,
        "timestamp": ServerValue.timestamp,
        "lastPing": ServerValue.timestamp,
        "offlineNotified": false,
        
        // 🔥 Init sırasında da gönder
        if (_companyId != null) "companyId": _companyId,
        if (_fcmToken != null) "fcmToken": _fcmToken,
        if (_activePlate != null) "activePlate": _activePlate,
      };

      await _db.child("locations/$driverId").update(data);

      // 🔥 onDisconnect'i yeniden ayarla
      await _setupDisconnectHandler();

      debugPrint("✅ Set online");
    } catch (e) {
      debugPrint("❌ Set online error: $e");
    }
  }

  Future<void> _setOffline() async {
    try {
      await _db.child("locations/$driverId").update({
        "isOnline": false,
        "timestamp": ServerValue.timestamp,
        "lastPing": ServerValue.timestamp,
      });
      debugPrint("⚠️ Set offline");
    } catch (e) {
      debugPrint("❌ Set offline error: $e");
    }
  }

  // ======================================================
  // CLEANUP - 🔥 İYİLEŞTİRİLDİ
  // ======================================================
  void dispose() {
    // Stream'leri iptal et
    _positionSub?.cancel();
    _jobSub?.cancel();

    // Timer'ları iptal et
    _updateTimer?.cancel();
    _permissionCheckTimer?.cancel();
    _historyCleanupTimer?.cancel();

    // Buffer'ı temizle
    _buffer.clear();

    // 🔥 Tüm state'i resetle
    _isTracking = false;
    _isUpdating = false;
    _isMoving = false;
    _isIdle = false;

    // Position verilerini temizle
    _lastPosition = null;
    _lastSentPosition = null;
    _lastMoveTime = null;

    debugPrint("🧹 Service disposed and cleaned up");
  }
}

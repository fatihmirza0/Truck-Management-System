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
  Timer? _historyCleanupTimer; // 🔥 YENİ: Otomatik temizlik

  Position? _lastPosition;
  LatLng? _lastSentPosition;
  DateTime? _lastMoveTime;

  bool _isTracking = false;
  bool _isUpdating = false;
  bool _isMoving = false;

  String _jobStatus = 'available';

  final List<Position> _buffer = [];

  // ======================================================
  // 🔥 HISTORY CONFIGURATION
  // ======================================================
  static const int _updateInterval = 10;
  static const int _idleTimeout = 300;
  static const int _bufferSize = 5;
  static const double _minMoveDistance = 10;
  static const double _minAccuracy = 30;

  // 🔥 YENİ: History ayarları
  static const double _historyMinDistance = 25.0; // 25m - rota gözüksün ama çok sık olmasın
  static const int _historyRetentionHours = 24; // 24 saat tut
  static const int _historyMaxPoints = 500; // Max 500 nokta tut
  static const int _historyCleanupIntervalHours = 24; // 30dk'da bir temizle

  DriverLocationService(this.driverId);

  bool get isTracking => _isTracking;

  // ======================================================
  // START
  // ======================================================
  Future<void> startTracking() async {
    if (_isTracking) return;
    _isTracking = true;

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
    await _setOnline();

    // onDisconnect
    _db.child("locations/$driverId").onDisconnect().update({
      "isOnline": false,
      "lastPing": ServerValue.timestamp,
    });

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(_onLocation);

    _updateTimer = Timer.periodic(
      const Duration(seconds: _updateInterval),
          (_) => _updateToRTDB(),
    );

    _permissionCheckTimer = Timer.periodic(
      const Duration(seconds: 10),
          (_) => _checkLocationPermission(),
    );

    // 🔥 YENİ: History temizlik timer'ı
    _historyCleanupTimer = Timer.periodic(
      const Duration(hours: _historyCleanupIntervalHours),
          (_) => _cleanupOldHistory(),
    );

    _listenJobStatus();

    // 🔥 İlk başlangıçta bir kere temizlik yap
    _cleanupOldHistory();

    debugPrint("✅ Tracking started");
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.status;

    if (!status.isGranted && _isTracking) {
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
  // STOP
  // ======================================================
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    _isTracking = false;

    await _positionSub?.cancel();
    await _jobSub?.cancel();
    _updateTimer?.cancel();
    _permissionCheckTimer?.cancel();
    _historyCleanupTimer?.cancel(); // 🔥 YENİ

    await _setOffline();

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

  void _listenJobStatus() {
    _jobSub =
        _firestore.collection('users').doc(driverId).snapshots().listen((doc) {
          if (doc.exists) {
            final newStatus = doc['jobStatus'] ?? 'available';
            if (_jobStatus != newStatus) {
              _jobStatus = newStatus;
              debugPrint("🔄 Job status changed: $_jobStatus");
              _updateToRTDB();
            }
          }
        });
  }

  // ======================================================
  // LOCATION HANDLING
  // ======================================================
  void _onLocation(Position pos) {
    if (pos.accuracy > _minAccuracy) return;

    _lastPosition = pos;
    _buffer.add(pos);

    if (_buffer.length > _bufferSize) {
      _buffer.removeAt(0);
    }

    _calculateMovement();
  }

  void _calculateMovement() {
    if (_buffer.length < 2) return;

    double distance = 0;
    int time = 0;

    for (int i = 1; i < _buffer.length; i++) {
      final a = _buffer[i - 1];
      final b = _buffer[i];

      distance += Geolocator.distanceBetween(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      );

      time += b.timestamp.difference(a.timestamp).inSeconds;
    }

    if (time == 0) return;

    final speed = (distance / time) * 3.6;
    _isMoving = distance >= 15 && speed > 5;

    if (_isMoving) {
      _lastMoveTime = DateTime.now();
    }
  }

  // ======================================================
  // RTDB UPDATE
  // ======================================================
  Future<void> _updateToRTDB() async {
    if (_lastPosition == null || _isUpdating) return;
    _isUpdating = true;

    try {
      final now = DateTime.now();

      if (_jobStatus == 'available' &&
          !_isMoving &&
          _lastMoveTime != null &&
          now.difference(_lastMoveTime!).inSeconds > _idleTimeout) {
        await _setOffline();
        return;
      }

      bool shouldAddToHistory = false;
      if (_lastSentPosition != null) {
        final d = Geolocator.distanceBetween(
          _lastSentPosition!.latitude,
          _lastSentPosition!.longitude,
          _lastPosition!.latitude,
          _lastPosition!.longitude,
        );

        // 🔥 YENİ: History için configurable threshold
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
        if (_isMoving || _jobStatus == 'busy') "offlineNotified": false,
      };

      await _db.child("locations/$driverId").update(data);

      if (shouldAddToHistory) {
        await _addToHistory(data);
        debugPrint("📍 Added to history (${_historyMinDistance}m threshold)");
      }

      _lastSentPosition =
          LatLng(_lastPosition!.latitude, _lastPosition!.longitude);

      debugPrint(
          "📍 Location updated: online (moving: $_isMoving, job: $_jobStatus)");
    } catch (e) {
      debugPrint("❌ RTDB update error: $e");
    } finally {
      _isUpdating = false;
    }
  }

  double _calcSpeed() {
    if (_buffer.length < 2) return 0;

    double dist = 0;
    int time = 0;

    for (int i = 1; i < _buffer.length; i++) {
      dist += Geolocator.distanceBetween(
        _buffer[i - 1].latitude,
        _buffer[i - 1].longitude,
        _buffer[i].latitude,
        _buffer[i].longitude,
      );
      time +=
          _buffer[i].timestamp.difference(_buffer[i - 1].timestamp).inSeconds;
    }

    return time == 0 ? 0 : (dist / time) * 3.6;
  }

  // ======================================================
  // 🔥 HISTORY MANAGEMENT - YENİ BÖLÜM
  // ======================================================

  /// History'e yeni nokta ekle
  Future<void> _addToHistory(Map data) async {
    try {
      await _db.child("history/$driverId").push().set({
        "lat": data['lat'],
        "lng": data['lng'],
        "timestamp": ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint("⚠️ History add error: $e");
    }
  }

  /// 🔥 YENİ: Eski history kayıtlarını temizle
  Future<void> _cleanupOldHistory() async {
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

      // Tüm history noktalarını topla
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

      // Timestamp'e göre sırala (en eski -> en yeni)
      entries.sort((a, b) => a.value.compareTo(b.value));

      final List<String> keysToDelete = [];

      // 1️⃣ Zaman bazlı temizlik: _historyRetentionHours'dan eski olanlar
      for (final entry in entries) {
        final entryTime = DateTime.fromMillisecondsSinceEpoch(entry.value);
        if (entryTime.isBefore(cutoffTime)) {
          keysToDelete.add(entry.key);
        }
      }

      // 2️⃣ Boyut bazlı temizlik: Max _historyMaxPoints nokta tut
      final remainingCount = entries.length - keysToDelete.length;
      if (remainingCount > _historyMaxPoints) {
        final excessCount = remainingCount - _historyMaxPoints;

        // En eski noktalardan başla (zaten silinecekler hariç)
        final notMarkedForDeletion = entries
            .where((e) => !keysToDelete.contains(e.key))
            .toList();

        for (int i = 0; i < excessCount && i < notMarkedForDeletion.length; i++) {
          keysToDelete.add(notMarkedForDeletion[i].key);
        }
      }

      if (keysToDelete.isEmpty) {
        debugPrint("✅ No history to delete (${entries.length} points)");
        return;
      }

      // Toplu silme işlemi
      final updates = <String, dynamic>{};
      for (final key in keysToDelete) {
        updates[key] = null; // RTDB'de null = delete
      }

      await historyRef.update(updates);

      final remainingPoints = entries.length - keysToDelete.length;
      debugPrint(
          "🧹 Cleaned ${keysToDelete.length} old history points. "
              "Remaining: $remainingPoints (max: $_historyMaxPoints, "
              "retention: ${_historyRetentionHours}h)"
      );

    } catch (e) {
      debugPrint("❌ History cleanup error: $e");
    }
  }

  /// 🔥 YENİ: Manuel history temizleme (isteğe bağlı - test/debug için)
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
      await _db.child("locations/$driverId").update({
        "lat": _lastPosition!.latitude,
        "lng": _lastPosition!.longitude,
        "isOnline": true,
        "timestamp": ServerValue.timestamp,
        "lastPing": ServerValue.timestamp,
        "offlineNotified": false,
      });
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
  // CLEANUP
  // ======================================================
  void dispose() {
    _positionSub?.cancel();
    _jobSub?.cancel();
    _updateTimer?.cancel();
    _permissionCheckTimer?.cancel();
    _historyCleanupTimer?.cancel();
  }
}
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;

class DriverLocationService {
  final String driverId;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  StreamSubscription<Position>? _positionStream;
  Timer? _idleCheckTimer;

  DateTime? _lastUpdateTime;
  DateTime? _lastMovementTime;
  bool _isMoving = false;
  Position? _lastPosition;
  Position? _lastSignificantPosition;
  List<Position> _recentPositions = [];

  // Ayarlar
  static const int _idleTimeoutSeconds = 300; // 5 dakika hareketsizlik
  static const double _minDistanceForMovement = 15.0; // 15 metre hareket gerekli
  static const double _minAccuracyThreshold = 30.0; // 30 metre accuracy limiti
  static const int _positionHistoryCount = 5; // Son 5 pozisyonu tut
  static const int _updateIntervalMoving = 10; // saniye
  static const int _updateIntervalIdle = 60; // saniye
  static const int _historyRetentionHours = 24; // 24 saat geçmiş

  DriverLocationService(this.driverId);

  // ======================================================
  // START TRACKING
  // ======================================================
  Future<void> startTracking() async {
    if (kIsWeb) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Konum izni kalıcı olarak reddedildi');
    }

    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // 10 metre hareket gerekli
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPosition, onError: (e) {
      print('❌ Position stream error: $e');
    });

    // Hareketsizlik kontrolü
    _idleCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
          (_) => _checkIdleStatus(),
    );

    await _setStatus('online');
  }

  // ======================================================
  // STOP TRACKING
  // ======================================================
  Future<void> stopTracking() async {
    await _positionStream?.cancel();
    _idleCheckTimer?.cancel();
    _positionStream = null;
    _idleCheckTimer = null;
    await _setStatus('offline');
  }

  // ======================================================
  // POSITION UPDATE
  // ======================================================
  Future<void> _onPosition(Position position) async {
    final now = DateTime.now();

    // 1. Accuracy kontrolü - Kötü sinyali filtrele
    if (position.accuracy > _minAccuracyThreshold) {
      print('⚠️ Poor GPS accuracy: ${position.accuracy.toStringAsFixed(1)}m - Skipping');
      return;
    }

    // 2. Son pozisyonları tut
    _recentPositions.add(position);
    if (_recentPositions.length > _positionHistoryCount) {
      _recentPositions.removeAt(0);
    }

    // 3. Mesafe bazlı hareket kontrolü
    final wasMoving = _isMoving;
    double actualSpeed = 0.0;
    double distanceMoved = 0.0;

    if (_lastSignificantPosition != null) {
      // Son önemli pozisyondan bu yana kat edilen mesafe
      distanceMoved = Geolocator.distanceBetween(
        _lastSignificantPosition!.latitude,
        _lastSignificantPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      // Ortalama hız hesapla (son 3 pozisyondan)
      if (_recentPositions.length >= 3) {
        actualSpeed = _calculateAverageSpeed();
      }

      // Hareket kontrolü: En az 15 metre hareket gerekli
      _isMoving = distanceMoved >= _minDistanceForMovement && actualSpeed > 5.0; // 5 km/h
    } else {
      _lastSignificantPosition = position;
    }

    // 4. Hareket değişimi - otomatik online/offline
    if (_isMoving && !wasMoving) {
      _lastMovementTime = now;
      _lastSignificantPosition = position;
      await _setStatus('online');
      print('🚗 Hareket başladı - Online');
    }

    // 5. Güncelleme aralığı kontrolü
    if (_lastUpdateTime != null) {
      final diff = now.difference(_lastUpdateTime!).inSeconds;
      final minInterval = _isMoving ? _updateIntervalMoving : _updateIntervalIdle;

      // Hareket durumu değişmediyse ve süre dolmadıysa skip
      if (diff < minInterval && wasMoving == _isMoving && distanceMoved < _minDistanceForMovement) {
        return;
      }
    }

    // 6. Önemli pozisyon güncellemesi (hareket halindeyse)
    if (_isMoving && distanceMoved >= _minDistanceForMovement) {
      _lastSignificantPosition = position;
    }

    _lastUpdateTime = now;
    _lastPosition = position;

    // 7. Veriyi hazırla
    final data = {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'speed': _isMoving ? actualSpeed : 0.0, // Gerçek hız
      'heading': position.heading,
      'accuracy': position.accuracy,
      'isMoving': _isMoving,
      'timestamp': ServerValue.timestamp,
    };

    try {
      final baseRef = _db.child('driver_locations').child(driverId);

      // Current location
      await baseRef.child('current').set(data);

      // History - sadece anlamlı hareketlerde kaydet
      if (_isMoving && distanceMoved >= _minDistanceForMovement) {
        await baseRef.child('history').push().set(data);
      } else if (_shouldSaveToHistory()) {
        // Durağan halde de periyodik kaydet
        await baseRef.child('history').push().set(data);
      }

      // Cleanup old history
      await _cleanupHistory(baseRef.child('history'));

      print('📍 Location updated - Moving: $_isMoving, Speed: ${actualSpeed.toStringAsFixed(1)} km/h, Distance: ${distanceMoved.toStringAsFixed(1)}m');
    } catch (e) {
      print('❌ Location update error: $e');
    }
  }

  // ======================================================
  // CALCULATE AVERAGE SPEED
  // ======================================================
  double _calculateAverageSpeed() {
    if (_recentPositions.length < 2) return 0.0;

    double totalDistance = 0.0;
    int totalTime = 0;

    for (int i = 1; i < _recentPositions.length; i++) {
      final prev = _recentPositions[i - 1];
      final curr = _recentPositions[i];

      final distance = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        curr.latitude,
        curr.longitude,
      );

      final timeDiff = curr.timestamp.difference(prev.timestamp).inSeconds;

      if (timeDiff > 0) {
        totalDistance += distance;
        totalTime += timeDiff;
      }
    }

    if (totalTime == 0) return 0.0;

    // m/s -> km/h
    final speedMps = totalDistance / totalTime;
    return speedMps * 3.6;
  }

  // ======================================================
  // IDLE STATUS CHECK
  // ======================================================
  Future<void> _checkIdleStatus() async {
    if (_lastMovementTime == null) return;

    final now = DateTime.now();
    final idleDuration = now.difference(_lastMovementTime!).inSeconds;

    // 5 dakika hareketsizse offline yap
    if (idleDuration > _idleTimeoutSeconds && !_isMoving) {
      await _setStatus('offline');
    }
  }

  // ======================================================
  // HISTORY SAVE LOGIC
  // ======================================================
  bool _shouldSaveToHistory() {
    // Her 5 dakikada bir kaydet (durağan haldeyken)
    if (_lastUpdateTime == null) return true;
    final diff = DateTime.now().difference(_lastUpdateTime!).inMinutes;
    return diff >= 5;
  }

  // ======================================================
  // CLEAN OLD HISTORY
  // ======================================================
  Future<void> _cleanupHistory(DatabaseReference historyRef) async {
    try {
      final snap = await historyRef.get();
      if (!snap.exists) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final limit = now - (_historyRetentionHours * 60 * 60 * 1000);

      final data = snap.value as Map<dynamic, dynamic>;
      final deleteOps = <Future<void>>[];

      data.forEach((key, value) {
        final ts = value['timestamp'] as int? ?? 0;
        if (ts < limit) {
          deleteOps.add(historyRef.child(key.toString()).remove());
        }
      });

      if (deleteOps.isNotEmpty) {
        await Future.wait(deleteOps);
        print('🧹 Cleaned ${deleteOps.length} old history entries');
      }
    } catch (e) {
      print('⚠️ History cleanup error: $e');
    }
  }

  // ======================================================
  // STATUS MANAGEMENT
  // ======================================================
  Future<void> _setStatus(String status, {String? jobId}) async {
    final statusData = {
      'status': status,
      'lastSeen': ServerValue.timestamp,
    };

    if (jobId != null) {
      statusData['currentJobId'] = jobId;
    }

    await _db
        .child('driver_locations')
        .child(driverId)
        .child('status')
        .set(statusData);

    print('📍 Status updated: $status');
  }

  // ======================================================
  // PUBLIC METHODS
  // ======================================================
  Future<void> updateDriverStatus(String status, {String? jobId}) async {
    await _setStatus(status, jobId: jobId);

    // Status değişikliğinde hareket zamanını güncelle
    if (status == 'online' || status == 'busy') {
      _lastMovementTime = DateTime.now();
    }
  }

  // Firestore'daki jobStatus ile RTDB'yi senkronize et
  Future<void> syncJobStatus(String firestoreJobStatus) async {
    String rtdbStatus;

    switch (firestoreJobStatus) {
      case 'available':
        rtdbStatus = 'online';
        break;
      case 'busy':
        rtdbStatus = 'busy';
        break;
      case 'offline':
        rtdbStatus = 'offline';
        break;
      default:
        rtdbStatus = 'online';
    }

    await _setStatus(rtdbStatus);
    print('🔄 Synced Firestore ($firestoreJobStatus) → RTDB ($rtdbStatus)');
  }

  bool get isTracking => _positionStream != null;
  bool get isMoving => _isMoving;
  Position? get lastPosition => _lastPosition;

  void dispose() {
    _positionStream?.cancel();
    _idleCheckTimer?.cancel();
    _recentPositions.clear();
  }
}
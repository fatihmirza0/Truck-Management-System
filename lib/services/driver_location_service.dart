import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';

class DriverLocationService {
  final String driverId;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<Position>? _positionStream;
  Timer? _idleCheckTimer;
  StreamSubscription<DocumentSnapshot>? _jobStatusListener;

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

    // ✅ RTDB'deki mevcut durumu kontrol et
    final currentStatusSnap = await _db
        .child('driver_locations')
        .child(driverId)
        .child('status')
        .get();

    if (currentStatusSnap.exists) {
      final statusData = currentStatusSnap.value as Map<dynamic, dynamic>;
      final currentStatus = statusData['status'] as String?;

      // Eğer zaten online/busy ise, tekrar başlatma
      if (currentStatus == 'online' || currentStatus == 'busy') {
        print('⚠️ Tracking zaten aktif: $currentStatus');
        return;
      }
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Konum izni kalıcı olarak reddedildi');
    }

    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
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

    // ✅ Firestore jobStatus'u dinle ve RTDB'yi senkronize et
    _startJobStatusListener();

    // ✅ Firestore'dan mevcut jobStatus'a göre başlangıç durumu belirle
    final userDoc = await _firestore.collection('users').doc(driverId).get();
    if (!userDoc.exists) {
      print('❌ User document not found');
      return;
    }

    final userData = userDoc.data()!;
    final jobStatus = userData['jobStatus'] as String? ?? 'available';
    final currentJobId = userData['currentJobId'] as String?;

    // ✅ Firestore jobStatus → RTDB status mapping
    // Firestore: available | busy
    // RTDB: online | busy | offline
    String rtdbStatus;
    if (jobStatus == 'busy') {
      rtdbStatus = 'busy';
    } else {
      // available ise RTDB'de online
      rtdbStatus = 'online';
    }

    await _setStatus(rtdbStatus, jobId: currentJobId);
    print('🚀 Tracking başlatıldı - RTDB: $rtdbStatus (Firestore jobStatus: $jobStatus)');
  }

  // ======================================================
  // STOP TRACKING
  // ======================================================
  Future<void> stopTracking() async {
    await _positionStream?.cancel();
    _idleCheckTimer?.cancel();
    _jobStatusListener?.cancel();

    _positionStream = null;
    _idleCheckTimer = null;
    _jobStatusListener = null;

    // ✅ RTDB'de offline yap (Firestore'da değişiklik yok)
    await _setStatus('offline');
    print('🛑 Tracking durduruldu - RTDB: offline');
  }

  // ======================================================
  // JOB STATUS LISTENER (FIRESTORE → RTDB SYNC)
  // ======================================================
  void _startJobStatusListener() {
    _jobStatusListener = _firestore
        .collection('users')
        .doc(driverId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final jobStatus = data['jobStatus'] as String? ?? 'available';
      final currentJobId = data['currentJobId'] as String?;

      // ✅ Firestore jobStatus → RTDB status mapping
      // Firestore: available | busy
      // RTDB: online | busy | offline
      String rtdbStatus;
      if (jobStatus == 'busy') {
        rtdbStatus = 'busy';
      } else {
        // available ise RTDB'de online
        rtdbStatus = 'online';
      }

      await _setStatus(rtdbStatus, jobId: currentJobId);
      print('🔄 Sync: Firestore jobStatus=$jobStatus → RTDB status=$rtdbStatus');
    });
  }

  // ======================================================
  // POSITION UPDATE
  // ======================================================
  Future<void> _onPosition(Position position) async {
    final now = DateTime.now();

    // 1. Accuracy kontrolü
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
      distanceMoved = Geolocator.distanceBetween(
        _lastSignificantPosition!.latitude,
        _lastSignificantPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      if (_recentPositions.length >= 3) {
        actualSpeed = _calculateAverageSpeed();
      }

      _isMoving = distanceMoved >= _minDistanceForMovement && actualSpeed > 5.0;
    } else {
      _lastSignificantPosition = position;
    }

    // 4. Hareket değişimi
    if (_isMoving && !wasMoving) {
      _lastMovementTime = now;
      _lastSignificantPosition = position;
      print('🚗 Hareket başladı');
    }

    // 5. Güncelleme aralığı kontrolü
    if (_lastUpdateTime != null) {
      final diff = now.difference(_lastUpdateTime!).inSeconds;
      final minInterval = _isMoving ? _updateIntervalMoving : _updateIntervalIdle;

      if (diff < minInterval && wasMoving == _isMoving && distanceMoved < _minDistanceForMovement) {
        return;
      }
    }

    // 6. Önemli pozisyon güncellemesi
    if (_isMoving && distanceMoved >= _minDistanceForMovement) {
      _lastSignificantPosition = position;
    }

    _lastUpdateTime = now;
    _lastPosition = position;

    // 7. Veriyi hazırla
    final data = {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'speed': _isMoving ? actualSpeed : 0.0,
      'heading': position.heading,
      'accuracy': position.accuracy,
      'isMoving': _isMoving,
      'timestamp': ServerValue.timestamp,
    };

    try {
      final baseRef = _db.child('driver_locations').child(driverId);

      // Current location
      await baseRef.child('current').set(data);

      // History
      if (_isMoving && distanceMoved >= _minDistanceForMovement) {
        await baseRef.child('history').push().set(data);
      } else if (_shouldSaveToHistory()) {
        await baseRef.child('history').push().set(data);
      }

      // Cleanup old history
      await _cleanupHistory(baseRef.child('history'));

      print('📍 Location updated - Moving: $_isMoving, Speed: ${actualSpeed.toStringAsFixed(1)} km/h');
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

    // ✅ RTDB'deki mevcut durumu kontrol et
    final currentStatusSnap = await _db
        .child('driver_locations')
        .child(driverId)
        .child('status')
        .get();

    if (!currentStatusSnap.exists) return;

    final statusData = currentStatusSnap.value as Map<dynamic, dynamic>;
    final currentStatus = statusData['status'] as String?;

    // ✅ Busy değilse ve 5 dakika hareketsizse offline yap
    if (currentStatus != 'busy' && idleDuration > _idleTimeoutSeconds && !_isMoving) {
      await _setStatus('offline');
      print('😴 5 dakika hareketsizlik - RTDB: offline');
    }
  }

  // ======================================================
  // HISTORY SAVE LOGIC
  // ======================================================
  bool _shouldSaveToHistory() {
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

    print('📍 RTDB Status updated: $status');
  }

  // ======================================================
  // PUBLIC METHODS
  // ======================================================

  bool get isTracking => _positionStream != null;
  bool get isMoving => _isMoving;
  Position? get lastPosition => _lastPosition;

  void dispose() {
    _positionStream?.cancel();
    _idleCheckTimer?.cancel();
    _jobStatusListener?.cancel();
    _recentPositions.clear();
  }
}
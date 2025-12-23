import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;

class DriverLocationService {
  final String driverId;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  StreamSubscription<Position>? _positionStream;
  DateTime? _lastUpdateTime;
  bool _isMoving = false;

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
      throw Exception('Konum izni reddedildi');
    }

    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: settings)
            .listen(_onPosition);

    await _setStatus('online');
  }

  // ======================================================
  // STOP TRACKING
  // ======================================================
  Future<void> stopTracking() async {
    await _positionStream?.cancel();
    await _setStatus('offline');
  }

  // ======================================================
  // POSITION UPDATE
  // ======================================================
  Future<void> _onPosition(Position position) async {
    final now = DateTime.now();

    _isMoving = position.speed > 0.5;

    if (_lastUpdateTime != null) {
      final diff = now.difference(_lastUpdateTime!).inSeconds;
      final minInterval = _isMoving ? 10 : 60;
      if (diff < minInterval) return;
    }

    _lastUpdateTime = now;

    final data = {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'speed': position.speed * 3.6,
      'heading': position.heading,
      'isMoving': _isMoving,
      'timestamp': ServerValue.timestamp,
    };

    try {
      final baseRef = _db.child('driver_locations').child(driverId);

      // current
      await baseRef.child('current').set(data);

      // history
      await baseRef.child('history').push().set(data);

      // cleanup
      await _cleanupHistory(baseRef.child('history'));
    } catch (e) {
      print('❌ Location update error: $e');
    }
  }

  // ======================================================
  // CLEAN OLD HISTORY (1 SAAT)
  // ======================================================
  Future<void> _cleanupHistory(DatabaseReference historyRef) async {
    final snap = await historyRef.get();
    if (!snap.exists) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final limit = now - (60 * 60 * 1000);

    final data = snap.value as Map<dynamic, dynamic>;
    data.forEach((key, value) {
      final ts = value['timestamp'] as int? ?? 0;
      if (ts < limit) {
        historyRef.child(key).remove();
      }
    });
  }

  // ======================================================
  // STATUS
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
  }

  Future<void> updateDriverStatus(String status, {String? jobId}) async {
    await _setStatus(status, jobId: jobId);
  }

  void dispose() {
    _positionStream?.cancel();
  }
}

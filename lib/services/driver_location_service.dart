import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

class DriverLocationService {
  final String driverId;

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<DocumentSnapshot>? _jobSub;
  Timer? _updateTimer;

  Position? _lastPosition;
  LatLng? _lastSentPosition;
  DateTime? _lastMoveTime;

  bool _isTracking = false;
  bool _isUpdating = false;
  bool _isMoving = false;

  String _jobStatus = 'available';
  String _rtdbStatus = 'offline';

  final List<Position> _buffer = [];

  // ================= CONFIG =================
  static const int _updateInterval = 10; // saniye
  static const int _idleTimeout = 300; // 5 dk
  static const int _bufferSize = 5;
  static const double _minMoveDistance = 10;
  static const double _minAccuracy = 30;

  DriverLocationService(this.driverId);

  bool get isTracking => _isTracking;

  // ======================================================
  // START
  // ======================================================
  Future<void> startTracking() async {
    if (_isTracking) return;
    _isTracking = true;

    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permission denied");
    }

    await _initLocation();
    await _setOnline();

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

    _listenJobStatus();

    debugPrint("✅ Tracking started");
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

    await _setOffline();

    _positionSub = null;
    _jobSub = null;
    _updateTimer = null;

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
    _jobSub = _firestore
        .collection('users')
        .doc(driverId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final newStatus = doc['jobStatus'] ?? 'available';
        if (_jobStatus != newStatus) {
          _jobStatus = newStatus;
          debugPrint("🔄 Job status changed: $_jobStatus");
          // Status değiştiğinde hemen RTDB'yi güncelle
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
  // RTDB UPDATE - DÜZELTİLDİ ✅
  // ======================================================
  Future<void> _updateToRTDB() async {
    if (_lastPosition == null || _isUpdating) return;
    _isUpdating = true;

    try {
      final now = DateTime.now();

      // 🔥 SADECE AVAILABLE VE DURGUN SÜRÜCÜLER İÇİN OFFLINE KONTROLÜ
      if (_jobStatus == 'available' &&
          !_isMoving &&
          _lastMoveTime != null &&
          now.difference(_lastMoveTime!).inSeconds > _idleTimeout) {
        if (_rtdbStatus != "offline") {
          await _setOffline();
        }
        return;
      }

      // 🔥 History için mesafe kontrolü
      bool shouldAddToHistory = false;
      if (_lastSentPosition != null) {
        final d = Geolocator.distanceBetween(
          _lastSentPosition!.latitude,
          _lastSentPosition!.longitude,
          _lastPosition!.latitude,
          _lastPosition!.longitude,
        );

        // 50m'den fazla hareket varsa history'ye ekle
        shouldAddToHistory = d >= 50;

        // Busy değilse ve minimum mesafe yoksa skip
        if (_jobStatus != 'busy' && d < _minMoveDistance && !_isMoving) return;
      } else {
        // İlk konum, history'ye ekle
        shouldAddToHistory = true;
      }

      // Status belirleme
      final currentStatus = _jobStatus == 'busy' ? 'busy' : 'online';

      final data = {
        "lat": _lastPosition!.latitude,
        "lng": _lastPosition!.longitude,
        "heading": _lastPosition!.heading.isNaN ? 0 : _lastPosition!.heading,
        "speed": _isMoving ? _calcSpeed() : 0,
        "accuracy": _lastPosition!.accuracy,
        "isMoving": _isMoving,
        "status": currentStatus,
        "timestamp": ServerValue.timestamp,
        "lastPing": ServerValue.timestamp,
      };

      await _db.child("locations/$driverId").update(data);

      // ✅ Anlamlı mesafe varsa history'ye ekle
      if (shouldAddToHistory) {
        await _addToHistory(data);
        debugPrint("📍 Added to history (${_lastSentPosition != null ? '${Geolocator.distanceBetween(_lastSentPosition!.latitude, _lastSentPosition!.longitude, _lastPosition!.latitude, _lastPosition!.longitude).toStringAsFixed(0)}m' : 'first'})");
      }

      _rtdbStatus = currentStatus;
      _lastSentPosition = LatLng(_lastPosition!.latitude, _lastPosition!.longitude);

      debugPrint("📍 Location updated: $currentStatus (moving: $_isMoving)");
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
      time += _buffer[i]
          .timestamp
          .difference(_buffer[i - 1].timestamp)
          .inSeconds;
    }

    return time == 0 ? 0 : (dist / time) * 3.6;
  }

  // ======================================================
  // HISTORY - ✅ DÜZELTİLDİ
  // ======================================================
  Future<void> _addToHistory(Map data) async {
    try {
      // Push ile otomatik unique key oluştur
      await _db.child("history/$driverId").push().set({
        "lat": data['lat'],
        "lng": data['lng'],
        "timestamp": ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint("⚠️ History add error: $e");
    }
  }

  // ======================================================
  // STATUS
  // ======================================================
  Future<void> _setOnline() async {
    if (_lastPosition == null) return;

    _rtdbStatus = _jobStatus == 'busy' ? 'busy' : 'online';

    try {
      await _db.child("locations/$driverId").update({
        "lat": _lastPosition!.latitude,
        "lng": _lastPosition!.longitude,
        "status": _rtdbStatus,
        "timestamp": ServerValue.timestamp,
        "lastPing": ServerValue.timestamp,
        "offlineNotified": false,
      });
      debugPrint("✅ Set online: $_rtdbStatus");
    } catch (e) {
      debugPrint("❌ Set online error: $e");
    }
  }

  Future<void> _setOffline() async {
    _rtdbStatus = "offline";

    try {
      await _db.child("locations/$driverId").update({
        "status": "offline",
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
  }
}
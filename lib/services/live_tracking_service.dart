import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// Model
class LiveDriver {
  final String driverId;
  final String name;
  final String plate;
  final String phone;
  final LatLng position;
  final double heading;
  final double speed;
  final double accuracy;
  final bool isMoving;
  final String status; // ✅ busy, online, offline
  final DateTime? lastSeen;
  final String? currentJobId;
  final List<LatLng> history;

  LiveDriver({
    required this.driverId,
    required this.name,
    required this.plate,
    required this.phone,
    required this.position,
    required this.heading,
    required this.speed,
    required this.accuracy,
    required this.isMoving,
    required this.status,
    this.lastSeen,
    this.currentJobId,
    required this.history,
  });
}

// Service
class LiveTrackingService {
  final _firestore = FirebaseFirestore.instance;

  static const String _endpoint =
      'https://us-central1-truck-dispatch-system.cloudfunctions.net/getLiveDriverLocations';

  static const int _pollingIntervalSeconds = 10;

  final Map<String, Map<String, dynamic>> _userCache = {};
  final Map<String, String> _jobStatusCache = {}; // ✅ driverId -> jobStatus

  StreamSubscription<QuerySnapshot>? _jobsSubscription;
  StreamSubscription<QuerySnapshot>? _usersSubscription;

  bool _isActive = false; // ✅ Service aktif mi kontrolü

  /// 🔥 Preload Firestore Data
  Future<void> preloadFirestore() async {
    try {
      // ✅ TEK SEFERLIK QUERY - Listener değil
      final users = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .where('isActive', isEqualTo: true)
          .where('softDeleted', isEqualTo: false)
          .get();

      for (final u in users.docs) {
        final d = u.data();

        _userCache[u.id] = {
          'name': d['name'] ?? '',
          'phone': d['phone'] ?? '',
          'activeVehicleId': d['activeVehicleId'],
        };

        // ✅ Job status cache
        _jobStatusCache[u.id] = d['jobStatus'] ?? 'available';
      }

      // ✅ TEK SEFERLIK QUERY - Vehicles
      final vehicleIds = _userCache.values
          .map((v) => v['activeVehicleId'])
          .where((id) => id != null)
          .toSet();

      if (vehicleIds.isNotEmpty) {
        final vehiclesSnap = await _firestore
            .collection('vehicles')
            .where(FieldPath.documentId, whereIn: vehicleIds.toList())
            .get();

        for (final vehicleDoc in vehiclesSnap.docs) {
          final plate = vehicleDoc.data()['plate'] ?? '';

          // Cache'de bu vehicle'ı kullanan driver'ı bul
          _userCache.forEach((driverId, data) {
            if (data['activeVehicleId'] == vehicleDoc.id) {
              data['plate'] = plate;
            }
          });
        }
      }

      debugPrint('✅ Preloaded ${_userCache.length} drivers');

      // ✅ Listener'ları başlat (sadece service aktifken)
      _startListeners();
    } catch (e) {
      debugPrint('❌ Preload error: $e');
    }
  }

  /// 🔥 Listener'ları başlat
  void _startListeners() {
    if (!_isActive) {
      _isActive = true;
      _startJobsListener();
      _startUsersListener();
    }
  }

  /// 🔥 Jobs Listener (SADECE busy cache için)
  void _startJobsListener() {
    _jobsSubscription?.cancel(); // Önceki listener varsa iptal et

    _jobsSubscription = _firestore
        .collection('jobs')
        .where('status', whereIn: ['approved', 'in_progress'])
        .snapshots(includeMetadataChanges: false) // ✅ Sadece server değişiklikleri
        .listen(
          (snapshot) {
        // ✅ SADECE DEĞİŞİKLİKLERİ İŞLE (tüm documents değil)
        for (final change in snapshot.docChanges) {
          final driverId = change.doc.get('driverId');
          if (driverId != null && driverId is String) {
            switch (change.type) {
              case DocumentChangeType.added:
              case DocumentChangeType.modified:
                _jobStatusCache[driverId] = 'busy';
                break;
              case DocumentChangeType.removed:
                _jobStatusCache[driverId] = 'available';
                break;
            }
          }
        }

        debugPrint('🔄 Jobs cache updated: ${snapshot.docChanges.length} changes');
      },
      onError: (e) {
        debugPrint('❌ Jobs listener error: $e');
      },
    );
  }

  /// 🔥 Users Listener (SADECE jobStatus değişiklikleri için)
  void _startUsersListener() {
    _usersSubscription?.cancel(); // Önceki listener varsa iptal et

    _usersSubscription = _firestore
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .snapshots(includeMetadataChanges: false) // ✅ Sadece server değişiklikleri
        .listen(
          (snapshot) {
        // ✅ SADECE DEĞİŞİKLİKLERİ İŞLE
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.modified ||
              change.type == DocumentChangeType.added) {
            final driverId = change.doc.id;
            final jobStatus = change.doc.data()?['jobStatus'] ?? 'available';
            _jobStatusCache[driverId] = jobStatus;
          }
        }

        debugPrint('🔄 JobStatus cache updated: ${snapshot.docChanges.length} changes');
      },
      onError: (e) {
        debugPrint('❌ Users listener error: $e');
      },
    );
  }

  /// 🔥 Listener'ları durdur
  void _stopListeners() {
    _jobsSubscription?.cancel();
    _usersSubscription?.cancel();
    _jobsSubscription = null;
    _usersSubscription = null;
    _isActive = false;
    debugPrint('⏸️ Listeners stopped');
  }

  /// 📍 Get User Data (cache'den)
  Map<String, dynamic> _getUserDataFromCache(String driverId) {
    if (_userCache.containsKey(driverId)) {
      return _userCache[driverId]!;
    }
    return {'name': '', 'phone': '', 'plate': ''};
  }

  /// 🌐 HTTP Polling - RTDB Data
  Stream<List<LiveDriver>> liveDrivers() async* {
    int errorCount = 0;

    // ✅ Service başladı
    _isActive = true;

    while (true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          debugPrint('⚠️ User not authenticated');
          yield <LiveDriver>[];
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }

        final token = await user.getIdToken();

        final res = await http
            .get(
          Uri.parse(_endpoint),
          headers: {'Authorization': 'Bearer $token'},
        )
            .timeout(const Duration(seconds: 10));

        if (res.statusCode == 401 || res.statusCode == 403) {
          debugPrint('❌ Auth error: ${res.statusCode}');
          yield <LiveDriver>[];
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }

        if (res.statusCode != 200) {
          debugPrint('⚠️ HTTP error: ${res.statusCode}');
          yield <LiveDriver>[];
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }

        if (res.body == 'null' || res.body.isEmpty || res.body == '{}') {
          yield <LiveDriver>[];
          await Future.delayed(Duration(seconds: _pollingIntervalSeconds));
          continue;
        }

        final raw = jsonDecode(res.body) as Map<String, dynamic>;

        final locations = raw['locations'] as Map<String, dynamic>?;
        final history = raw['history'] as Map<String, dynamic>?;

        if (locations == null) {
          yield <LiveDriver>[];
          await Future.delayed(Duration(seconds: _pollingIntervalSeconds));
          continue;
        }

        final List<LiveDriver> drivers = [];

        for (final entry in locations.entries) {
          final driverId = entry.key;
          final data = entry.value as Map<String, dynamic>;

          // ✅ Cache'den al (Firestore query yok)
          final userData = _getUserDataFromCache(driverId);

          final lat = (data['lat'] as num?)?.toDouble();
          final lng = (data['lng'] as num?)?.toDouble();

          if (lat == null || lng == null) {
            continue;
          }

          // ✅ History parse
          final List<LatLng> driverHistory = [];
          if (history != null && history[driverId] != null) {
            try {
              final h = history[driverId] as Map<String, dynamic>;

              final historyPoints = <MapEntry<String, dynamic>>[];
              h.forEach((key, value) {
                if (value is Map && value['lat'] != null && value['lng'] != null) {
                  historyPoints.add(MapEntry(key, value));
                }
              });

              historyPoints.sort((a, b) {
                final aTime = (a.value['timestamp'] as num?)?.toInt() ?? 0;
                final bTime = (b.value['timestamp'] as num?)?.toInt() ?? 0;
                return aTime.compareTo(bTime);
              });

              final recentPoints = historyPoints.length > 100
                  ? historyPoints.sublist(historyPoints.length - 100)
                  : historyPoints;

              for (final entry in recentPoints) {
                final hLat = (entry.value['lat'] as num?)?.toDouble();
                final hLng = (entry.value['lng'] as num?)?.toDouble();
                if (hLat != null && hLng != null) {
                  driverHistory.add(LatLng(hLat, hLng));
                }
              }
            } catch (e) {
              debugPrint('⚠️ History parse error for $driverId: $e');
            }
          }

          DateTime? lastSeen;
          if (data['timestamp'] != null) {
            try {
              lastSeen = DateTime.fromMillisecondsSinceEpoch(
                data['timestamp'] as int,
              );
            } catch (e) {
              debugPrint('⚠️ Timestamp parse error: $e');
            }
          }

          // ✅ STATUS BELİRLEME
          final isOnline = data['isOnline'] as bool? ?? false;
          final jobStatus = _jobStatusCache[driverId] ?? 'available';

          String finalStatus;
          if (!isOnline) {
            finalStatus = 'offline';
          } else if (jobStatus == 'busy') {
            finalStatus = 'busy';
          } else {
            finalStatus = 'online';
          }

          drivers.add(
            LiveDriver(
              driverId: driverId,
              name: userData['name'] ?? '',
              plate: userData['plate'] ?? '—',
              phone: userData['phone'] ?? '',
              position: LatLng(lat, lng),
              heading: (data['heading'] as num?)?.toDouble() ?? 0,
              speed: (data['speed'] as num?)?.toDouble() ?? 0,
              accuracy: (data['accuracy'] as num?)?.toDouble() ?? 0,
              isMoving: data['isMoving'] as bool? ?? false,
              status: finalStatus,
              lastSeen: lastSeen,
              currentJobId: null,
              history: driverHistory,
            ),
          );
        }

        if (errorCount > 0) {
          debugPrint('✅ Recovered - ${drivers.length} drivers');
          errorCount = 0;
        }

        yield drivers;
      } catch (e) {
        errorCount++;
        debugPrint('❌ Fetch error ($errorCount): $e');
        yield <LiveDriver>[];

        if (errorCount > 5) {
          debugPrint('⚠️ Too many errors');
          await Future.delayed(const Duration(seconds: 30));
          errorCount = 0;
          continue;
        }
      }

      await Future.delayed(Duration(seconds: _pollingIntervalSeconds));
    }
  }

  void dispose() {
    _stopListeners(); // ✅ Listener'ları kapat
    _userCache.clear();
    _jobStatusCache.clear();
    debugPrint('🧹 Service disposed');
  }

  void clearCache() {
    _userCache.clear();
    _jobStatusCache.clear();
    debugPrint('🧹 Cache cleared');
  }
}
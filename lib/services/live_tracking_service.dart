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
  final String status;
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

  // 🔥 Caches
  final Map<String, Map<String, dynamic>> _userCache = {};
  final Set<String> _busyDriversCache = {};

  // 🔥 Jobs Listener
  StreamSubscription<QuerySnapshot>? _jobsSubscription;

  /// 🔥 Preload Firestore Data
  Future<void> preloadFirestore() async {
    try {
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
      }

      // Load plates
      for (final entry in _userCache.entries) {
        final vehicleId = entry.value['activeVehicleId'];
        if (vehicleId != null) {
          try {
            final vehicleDoc =
            await _firestore.collection('vehicles').doc(vehicleId).get();

            if (vehicleDoc.exists) {
              entry.value['plate'] = vehicleDoc.data()?['plate'] ?? '';
            }
          } catch (e) {
            debugPrint('⚠️ Vehicle fetch error: $e');
          }
        }
      }

      debugPrint('✅ Preloaded ${_userCache.length} drivers');

      // Start jobs listener
      _startJobsListener();
    } catch (e) {
      debugPrint('❌ Preload error: $e');
    }
  }

  /// 🔥 Jobs Listener
  void _startJobsListener() {
    _jobsSubscription = _firestore
        .collection('jobs')
        .where('status', whereIn: ['approved', 'in_progress'])
        .snapshots(includeMetadataChanges: false)
        .listen(
          (snapshot) {
        if (snapshot.docChanges.isEmpty) return;

        for (final change in snapshot.docChanges) {
          final driverId = change.doc.get('driverId');
          if (driverId != null && driverId is String) {
            switch (change.type) {
              case DocumentChangeType.added:
              case DocumentChangeType.modified:
                _busyDriversCache.add(driverId);
                break;
              case DocumentChangeType.removed:
                _busyDriversCache.remove(driverId);
                break;
            }
          }
        }

        debugPrint('🔄 Jobs cache: ${_busyDriversCache.length} busy drivers');
      },
      onError: (e) {
        debugPrint('❌ Jobs listener error: $e');
      },
    );
  }

  /// 📍 Get User Data
  Future<Map<String, dynamic>> _getUserData(String driverId) async {
    if (_userCache.containsKey(driverId)) {
      return _userCache[driverId]!;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(driverId).get();

      if (!userDoc.exists) {
        return {'name': '', 'phone': '', 'plate': ''};
      }

      final userData = userDoc.data()!;
      String plate = '';

      final activeVehicleId = userData['activeVehicleId'];
      if (activeVehicleId != null) {
        final vehicleDoc =
        await _firestore.collection('vehicles').doc(activeVehicleId).get();

        if (vehicleDoc.exists) {
          plate = vehicleDoc.data()?['plate'] ?? '';
        }
      }

      final result = {
        'name': userData['name'] ?? '',
        'phone': userData['phone'] ?? '',
        'plate': plate,
      };

      _userCache[driverId] = result;
      return result;
    } catch (e) {
      debugPrint('⚠️ getUserData error: $e');
      return {'name': '', 'phone': '', 'plate': ''};
    }
  }

  /// 🌐 HTTP Polling - RTDB Data
  Stream<List<LiveDriver>> liveDrivers() async* {
    int errorCount = 0;

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

        // ✅ Parse new RTDB structure
        final raw = jsonDecode(res.body) as Map<String, dynamic>;

        // Check if we have locations and history separately
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

          // Get user data from cache
          final userData = await _getUserData(driverId);

          // Parse location data (flat structure)
          final lat = (data['lat'] as num?)?.toDouble();
          final lng = (data['lng'] as num?)?.toDouble();

          if (lat == null || lng == null) {
            debugPrint('⚠️ Invalid location for $driverId');
            continue;
          }

          // Get history for this driver
          final List<LatLng> driverHistory = [];
          if (history != null && history[driverId] != null) {
            try {
              final h = history[driverId] as Map<String, dynamic>;
              final sorted = h.entries.toList()
                ..sort((a, b) {
                  final aTime = (a.value as Map)['timestamp'] ?? 0;
                  final bTime = (b.value as Map)['timestamp'] ?? 0;
                  return aTime.compareTo(bTime);
                });

              for (final e in sorted) {
                final hLat = (e.value['lat'] as num?)?.toDouble();
                final hLng = (e.value['lng'] as num?)?.toDouble();
                if (hLat != null && hLng != null) {
                  driverHistory.add(LatLng(hLat, hLng));
                }
              }
            } catch (e) {
              debugPrint('⚠️ History parse error: $e');
            }
          }

          // LastSeen
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

          // Status from RTDB
          final rtdbStatus = data['status']?.toString() ?? 'online';

          // Check if busy from cache
          final isBusy = _busyDriversCache.contains(driverId);

          // Final status
          String finalStatus;
          if (rtdbStatus == 'offline') {
            finalStatus = 'offline';
          } else if (isBusy || rtdbStatus == 'busy') {
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
    _jobsSubscription?.cancel();
    _userCache.clear();
    _busyDriversCache.clear();
    debugPrint('🧹 Service disposed');
  }

  void clearCache() {
    _userCache.clear();
    _busyDriversCache.clear();
    debugPrint('🧹 Cache cleared');
  }
}
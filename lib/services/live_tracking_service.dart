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
  static const int _maxHistoryPoints = 100;

  final Map<String, Map<String, dynamic>> _userCache = {};
  final Map<String, String> _jobStatusCache = {};
  final Map<String, List<LatLng>> _historyCache = {}; // 🔥 YENİ: History cache

  StreamSubscription<QuerySnapshot>? _jobsSubscription;
  StreamSubscription<QuerySnapshot>? _usersSubscription;

  bool _isActive = false;
  bool _isDisposed = false; // 🔥 YENİ: Dispose kontrolü

  /// 🔥 Preload Firestore Data - İYİLEŞTİRİLDİ
  Future<void> preloadFirestore() async {
    if (_isDisposed) return;

    try {
      // Cache zaten doluysa tekrar yükleme
      if (_userCache.isNotEmpty && _isActive) {
        debugPrint('✅ Cache already loaded (${_userCache.length} drivers)');
        return;
      }

      final userData = await _firestore.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).get();
      final companyId = userData.data()?['companyId'];
      if (companyId == null) {
        debugPrint('⚠️ No companyId found for user');
        return;
      }

      final users = await _firestore
          .collection('users')
          .where('companyId', isEqualTo: companyId) // 🔥 SAAS
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

        _jobStatusCache[u.id] = d['jobStatus'] ?? 'available';
      }

      final Set<String> vehicleIds = _userCache.values
          .map((v) => v['activeVehicleId'])
          .whereType<String>() // 🔥 kilit nokta
          .toSet();

      if (vehicleIds.isNotEmpty) {
        // 🔥 Firestore'da whereIn max 10 item alır, batch'lere böl
        final batches = <List<String>>[];
        final idList = vehicleIds.toList(); // List<String>

        for (int i = 0; i < idList.length; i += 10) {
          batches.add(idList.sublist(i, i + 10 > idList.length ? idList.length : i + 10));
        }

        for (final batch in batches) {
          final vehiclesSnap = await _firestore
              .collection('vehicles')
              .where('companyId', isEqualTo: companyId) // 🔥 SAAS
              .where(FieldPath.documentId, whereIn: batch)
              .get();

          for (final vehicleDoc in vehiclesSnap.docs) {
            final plate = vehicleDoc.data()['plate'] ?? '';

            _userCache.forEach((driverId, data) {
              if (data['activeVehicleId'] == vehicleDoc.id) {
                data['plate'] = plate;
              }
            });
          }
        }
      }

      debugPrint('✅ Preloaded ${_userCache.length} drivers');

      // 🔥 Listener'ları sadece ilk kez başlat
      if (!_isActive) {
        _startListeners();
      }
    } catch (e) {
      debugPrint('❌ Preload error: $e');
    }
  }

  /// 🔥 Listener'ları başlat - İYİLEŞTİRİLDİ
  void _startListeners() async {
    if (_isActive || _isDisposed) return;

    final userData = await _firestore.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).get();
    final companyId = userData.data()?['companyId'];
    if (companyId == null) return;

    _isActive = true;
    _startJobsListener(companyId);
    _startUsersListener(companyId);
    debugPrint('✅ Listeners started');
  }

  /// 🔥 Jobs Listener - İYİLEŞTİRİLDİ
  void _startJobsListener(String companyId) {
    _jobsSubscription?.cancel();

    _jobsSubscription = _firestore
        .collection('jobs')
        .where('companyId', isEqualTo: companyId) // 🔥 SAAS
        .where('status', whereIn: ['approved', 'in_progress'])
        .snapshots(includeMetadataChanges: false)
        .listen(
          (snapshot) {
        if (_isDisposed) return;

        // 🔥 SADECE DEĞİŞİKLİKLERİ İŞLE
        for (final change in snapshot.docChanges) {
          try {
            final data = change.doc.data();
            if (data == null) continue;

            final driverId = data['driverId'];
            if (driverId == null || driverId is! String) continue;

            switch (change.type) {
              case DocumentChangeType.added:
              case DocumentChangeType.modified:
                _jobStatusCache[driverId] = 'busy';
                break;
              case DocumentChangeType.removed:
                _jobStatusCache[driverId] = 'available';
                break;
            }
          } catch (e) {
            debugPrint('⚠️ Job change error: $e');
          }
        }

        if (snapshot.docChanges.isNotEmpty) {
          debugPrint('🔄 Jobs cache updated: ${snapshot.docChanges.length} changes');
        }
      },
      onError: (e) {
        debugPrint('❌ Jobs listener error: $e');
      },
      cancelOnError: false,
    );
  }

  /// 🔥 Users Listener - İYİLEŞTİRİLDİ
  void _startUsersListener(String companyId) {
    _usersSubscription?.cancel();

    _usersSubscription = _firestore
        .collection('users')
        .where('companyId', isEqualTo: companyId) // 🔥 SAAS
        .where('role', isEqualTo: 'driver')
        .snapshots(includeMetadataChanges: false)
        .listen(
          (snapshot) {
        if (_isDisposed) return;

        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.modified ||
              change.type == DocumentChangeType.added) {
            try {
              final driverId = change.doc.id;
              final data = change.doc.data();
              if (data != null) {
                final jobStatus = data['jobStatus'] ?? 'available';
                _jobStatusCache[driverId] = jobStatus;

                // 🔥 Cache'i de güncelle
                if (_userCache.containsKey(driverId)) {
                  _userCache[driverId]!['name'] = data['name'] ?? '';
                  _userCache[driverId]!['phone'] = data['phone'] ?? '';
                }
              }
            } catch (e) {
              debugPrint('⚠️ User change error: $e');
            }
          }
        }

        if (snapshot.docChanges.isNotEmpty) {
          debugPrint('🔄 JobStatus cache updated: ${snapshot.docChanges.length} changes');
        }
      },
      onError: (e) {
        debugPrint('❌ Users listener error: $e');
      },
      cancelOnError: false,
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

  /// 🔥 History Parse - İYİLEŞTİRİLDİ (Cache ile)
  List<LatLng> _parseHistory(String driverId, Map<String, dynamic>? historyData) {
    if (historyData == null) {
      return _historyCache[driverId] ?? [];
    }

    try {
      final historyPoints = <MapEntry<String, dynamic>>[];

      historyData.forEach((key, value) {
        if (value is Map && value['lat'] != null && value['lng'] != null) {
          historyPoints.add(MapEntry(key, value));
        }
      });

      if (historyPoints.isEmpty) {
        return _historyCache[driverId] ?? [];
      }

      // Timestamp'e göre sırala
      historyPoints.sort((a, b) {
        final aTime = (a.value['timestamp'] as num?)?.toInt() ?? 0;
        final bTime = (b.value['timestamp'] as num?)?.toInt() ?? 0;
        return aTime.compareTo(bTime);
      });

      // Son N noktayı al
      final recentPoints = historyPoints.length > _maxHistoryPoints
          ? historyPoints.sublist(historyPoints.length - _maxHistoryPoints)
          : historyPoints;

      final result = <LatLng>[];
      for (final entry in recentPoints) {
        final hLat = (entry.value['lat'] as num?)?.toDouble();
        final hLng = (entry.value['lng'] as num?)?.toDouble();
        if (hLat != null && hLng != null) {
          result.add(LatLng(hLat, hLng));
        }
      }

      // 🔥 Cache'e kaydet
      _historyCache[driverId] = result;
      return result;
    } catch (e) {
      debugPrint('⚠️ History parse error for $driverId: $e');
      return _historyCache[driverId] ?? [];
    }
  }

  /// 🌐 HTTP Polling - RTDB Data - 🔥 İYİLEŞTİRİLDİ
  Stream<List<LiveDriver>> liveDrivers() async* {
    if (_isDisposed) {
      debugPrint('⚠️ Service is disposed, cannot start stream');
      return;
    }

    int errorCount = 0;
    _isActive = true;

    try {
      while (!_isDisposed) {
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
            if (_isDisposed) break;

            final driverId = entry.key;
            final data = entry.value as Map<String, dynamic>;

            final userData = _getUserDataFromCache(driverId);

            final lat = (data['lat'] as num?)?.toDouble();
            final lng = (data['lng'] as num?)?.toDouble();

            if (lat == null || lng == null) continue;

            // 🔥 History - Cache'den al veya parse et
            final driverHistory = _parseHistory(
              driverId,
              history?[driverId] as Map<String, dynamic>?,
            );

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

            // STATUS BELİRLEME
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
          if (_isDisposed) break;

          errorCount++;
          debugPrint('❌ Fetch error ($errorCount): $e');
          yield <LiveDriver>[];

          if (errorCount > 5) {
            debugPrint('⚠️ Too many errors, backing off...');
            await Future.delayed(const Duration(seconds: 30));
            errorCount = 0;
            continue;
          }
        }

        if (!_isDisposed) {
          await Future.delayed(Duration(seconds: _pollingIntervalSeconds));
        }
      }
    } finally {
      debugPrint('🛑 Live stream ended');
    }
  }

  /// 🔥 Dispose - İYİLEŞTİRİLDİ
  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;
    _stopListeners();
    _userCache.clear();
    _jobStatusCache.clear();
    _historyCache.clear(); // 🔥 YENİ
    debugPrint('🧹 Service disposed');
  }

  void clearCache() {
    _userCache.clear();
    _jobStatusCache.clear();
    _historyCache.clear(); // 🔥 YENİ
    debugPrint('🧹 Cache cleared');
  }
}
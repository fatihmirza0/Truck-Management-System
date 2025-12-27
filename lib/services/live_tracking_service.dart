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

  // 🔥 Cache'ler
  final Map<String, Map<String, dynamic>> _userCache = {};
  final Set<String> _busyDriversCache = {}; // ✅ Meşgul sürücüler cache'i

  // 🔥 Jobs Listener
  StreamSubscription<QuerySnapshot>? _jobsSubscription;

  /// 🔥 Firestore'dan KİMLİK VERİLERİ (Preload)
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

      // Plakaları da önbelleğe al
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

      debugPrint('✅ Preloaded ${_userCache.length} drivers from Firestore');

      // 🔥 Jobs dinlemeye başla
      _startJobsListener();
    } catch (e) {
      debugPrint('❌ Preload error: $e');
    }
  }

  /// 🔥 JOBS LİSTENER (En Minimal Data Transfer)
  void _startJobsListener() {
    // ✅ Firestore'dan SADECE driverId field'larını dinle
    // Not: Firestore snapshot'ları her zaman tüm document'i getirir,
    // ama biz sadece ihtiyacımız olan field'ı extract ediyoruz
    _jobsSubscription = _firestore
        .collection('jobs')
        .where('status', whereIn: ['approved', 'in_progress'])
        .snapshots(includeMetadataChanges: false) // ✅ Metadata değişikliklerini ignore et
        .listen(
          (snapshot) {
        // Sadece değişen documentleri işle (daha az CPU)
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

        debugPrint('🔄 Jobs cache updated: ${_busyDriversCache.length} busy drivers');
      },
      onError: (e) {
        debugPrint('❌ Jobs listener error: $e');
      },
    );
  }

  /// 📍 Firestore'dan tek sürücü bilgisi çek (cache miss durumunda)
  Future<Map<String, dynamic>> _getUserData(String driverId) async {
    // Cache'de varsa döndür
    if (_userCache.containsKey(driverId)) {
      return _userCache[driverId]!;
    }

    // Yoksa Firestore'dan çek
    try {
      final userDoc = await _firestore.collection('users').doc(driverId).get();

      if (!userDoc.exists) {
        debugPrint('⚠️ User not found in Firestore: $driverId');
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

      // Cache'e ekle
      _userCache[driverId] = result;
      debugPrint('✅ Cached user data for: $driverId');
      return result;
    } catch (e) {
      debugPrint('⚠️ getUserData error for $driverId: $e');
      return {'name': '', 'phone': '', 'plate': ''};
    }
  }

  /// 🌐 HTTP Polling ile RTDB verisi (Windows uyumlu)
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

        final res = await http.get(
          Uri.parse(_endpoint),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 10));

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
          debugPrint('⚠️ Empty response body - No drivers tracking');
          yield <LiveDriver>[];
          await Future.delayed(Duration(seconds: _pollingIntervalSeconds));
          continue;
        }

        final raw = jsonDecode(res.body) as Map<String, dynamic>;
        final List<LiveDriver> drivers = [];

        for (final entry in raw.entries) {
          final driverId = entry.key;
          final data = entry.value as Map<String, dynamic>;

          final current = data['current'];
          final status = data['status'];

          if (current == null) {
            debugPrint('⚠️ Driver $driverId has no current location yet');
            continue;
          }

          // Cache'den kullanıcı bilgisi
          final userData = await _getUserData(driverId);

          // History
          final List<LatLng> history = [];
          if (data['history'] != null) {
            try {
              final h = data['history'] as Map<String, dynamic>;
              final sorted = h.entries.toList()
                ..sort((a, b) => (a.value['timestamp'] ?? 0)
                    .compareTo(b.value['timestamp'] ?? 0));

              for (final e in sorted) {
                history.add(
                  LatLng(
                    (e.value['latitude'] as num).toDouble(),
                    (e.value['longitude'] as num).toDouble(),
                  ),
                );
              }
            } catch (e) {
              debugPrint('⚠️ History parse error for $driverId: $e');
            }
          }

          // lastSeen
          DateTime? lastSeen;
          if (status != null && status['lastSeen'] != null) {
            try {
              lastSeen = DateTime.fromMillisecondsSinceEpoch(
                status['lastSeen'] as int,
              );
            } catch (e) {
              debugPrint('⚠️ lastSeen parse error for $driverId: $e');
            }
          }

          // ✅ RTDB'den gelen status: online | busy | offline
          final rtdbStatus = status?['status']?.toString() ?? 'offline';

          // 🔥 CACHE'DEN İŞ DURUMU KONTROLÜ (Firestore'a istek yok!)
          final isBusy = _busyDriversCache.contains(driverId);

          // ✅ Final status kararı
          String finalStatus;
          if (rtdbStatus == 'offline') {
            finalStatus = 'offline';
          } else if (isBusy) {
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
              position: LatLng(
                (current['latitude'] as num).toDouble(),
                (current['longitude'] as num).toDouble(),
              ),
              heading: (current['heading'] as num?)?.toDouble() ?? 0,
              speed: (current['speed'] as num?)?.toDouble() ?? 0,
              accuracy: (current['accuracy'] as num?)?.toDouble() ?? 0,
              isMoving: current['isMoving'] as bool? ?? false,
              status: finalStatus,
              lastSeen: lastSeen,
              currentJobId: status?['currentJobId']?.toString(),
              history: history,
            ),
          );
        }

        // ✅ Başarılı fetch
        if (errorCount > 0) {
          debugPrint(
              '✅ Recovered from errors - ${drivers.length} drivers loaded');
          errorCount = 0;
        }

        yield drivers;
      } catch (e) {
        errorCount++;
        debugPrint('❌ Fetch error ($errorCount): $e');
        yield <LiveDriver>[];

        // Çok fazla hata varsa polling interval'i artır
        if (errorCount > 5) {
          debugPrint('⚠️ Too many errors, increasing polling interval');
          await Future.delayed(const Duration(seconds: 30));
          errorCount = 0;
          continue;
        }
      }

      // Polling interval
      await Future.delayed(Duration(seconds: _pollingIntervalSeconds));
    }
  }

  /// Cache'i temizle ve listener'ı durdur
  void dispose() {
    _jobsSubscription?.cancel();
    _userCache.clear();
    _busyDriversCache.clear();
    debugPrint('🧹 Service disposed');
  }

  /// Cache'i temizle (eski metot uyumluluğu için)
  void clearCache() {
    _userCache.clear();
    _busyDriversCache.clear();
    debugPrint('🧹 Cache cleared');
  }
}
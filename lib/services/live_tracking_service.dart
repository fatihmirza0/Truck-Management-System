import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';

import 'live_driver.dart';

class LiveTrackingService {
  final _firestore = FirebaseFirestore.instance;
  final _rtdb = FirebaseDatabase.instance.ref('driver_locations');

  final Map<String, String> _nameCache = {};
  final Map<String, String> _plateCache = {};

  /// 🔥 Firestore’dan KİMLİK VERİLERİ
  Future<void> preloadFirestore() async {
    final users = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .where('isActive', isEqualTo: true)
        .where('softDeleted', isEqualTo: false)
        .get();

    for (final u in users.docs) {
      final d = u.data();

      _nameCache[u.id] = (d['name'] ?? '').toString();
      _plateCache[u.id] = (d['activePlate'] ?? '').toString();
    }
  }

  /// 🔴 SADECE KONUM
  Stream<List<LiveDriver>> liveDrivers() {
    return _rtdb.onValue.map((event) {
      if (event.snapshot.value == null) return [];

      final raw = event.snapshot.value as Map<dynamic, dynamic>;
      final List<LiveDriver> drivers = [];

      raw.forEach((driverId, data) {
        final current = data['current'];
        final status = data['status'];

        if (current == null) return;

        drivers.add(
          LiveDriver(
            driverId: driverId,
            name: _nameCache[driverId] ?? '',
            plate: _plateCache[driverId] ?? '—',
            position: LatLng(
              (current['latitude'] as num).toDouble(),
              (current['longitude'] as num).toDouble(),
            ),
            heading: (current['heading'] ?? 0).toDouble(),
            isMoving: current['isMoving'] ?? false,
            status: status?['status'] ?? 'offline',
          ),
        );
      });

      return drivers;
    });
  }
}

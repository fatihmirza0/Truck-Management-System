import 'package:latlong2/latlong.dart';

import 'package:latlong2/latlong.dart';

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

class JobRoute {
  final String load;
  final String unload;

  JobRoute({required this.load, required this.unload});
}

import 'package:latlong2/latlong.dart';

class LiveDriver {
  final String driverId;
  final String name;
  final String plate;
  final LatLng position;
  final double heading;
  final bool isMoving;
  final String status;

  LiveDriver({
    required this.driverId,
    required this.name,
    required this.plate,
    required this.position,
    required this.heading,
    required this.isMoving,
    required this.status,
  });
}
class JobRoute {
  final String load;
  final String unload;

  JobRoute({required this.load, required this.unload});
}

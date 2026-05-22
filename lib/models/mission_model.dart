import 'package:cloud_firestore/cloud_firestore.dart';

class MissionRouteDetails {
  final String origin;
  final String destination;
  final double distanceKm;
  final String duration;

  const MissionRouteDetails({
    required this.origin,
    required this.destination,
    required this.distanceKm,
    required this.duration,
  });

  factory MissionRouteDetails.fromMap(Map<String, dynamic> map) {
    String parseWaypoint(dynamic val) {
      if (val == null) return '';
      if (val is String) return val;
      if (val is Map) return (val['name'] ?? '').toString();
      return val.toString();
    }

    double parseDistance(Map<String, dynamic> m) {
      final distKm = m['distanceKm'];
      if (distKm is num) return distKm.toDouble();
      if (distKm is String) {
        final clean = distKm.replaceAll(RegExp(r'[^0-9.]'), '');
        return double.tryParse(clean) ?? 0.0;
      }
      final dist = m['distance'];
      if (dist is num) return dist.toDouble();
      if (dist is String) {
        final clean = dist.replaceAll(RegExp(r'[^0-9.]'), '');
        return double.tryParse(clean) ?? 0.0;
      }
      return 0.0;
    }

    return MissionRouteDetails(
      origin: parseWaypoint(map['origin']),
      destination: parseWaypoint(map['destination']),
      distanceKm: parseDistance(map),
      duration: map['duration'] ?? '',
    );
  }
}

class MissionModel {
  final String id;
  final String companyId;
  final String driverId;
  final String status; // pending | in_progress | completed | rejected
  final double cargoTonnage;
  final MissionRouteDetails routeDetails;
  final DateTime? assignedAt;

  const MissionModel({
    required this.id,
    required this.companyId,
    required this.driverId,
    required this.status,
    required this.cargoTonnage,
    required this.routeDetails,
    this.assignedAt,
  });

  bool get isPending => status == 'pending';
  bool get isInProgress => status == 'in_progress';

  factory MissionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final routeMap = data['routeDetails'] as Map<String, dynamic>? ?? {};
    return MissionModel(
      id: doc.id,
      companyId: data['companyId'] ?? '',
      driverId: data['driverId'] ?? '',
      status: data['status'] ?? 'pending',
      cargoTonnage: (data['cargoTonnage'] as num?)?.toDouble() ?? 0.0,
      routeDetails: MissionRouteDetails.fromMap(routeMap),
      assignedAt: (data['assignedAt'] as Timestamp?)?.toDate(),
    );
  }
}

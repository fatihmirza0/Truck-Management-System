import 'package:cloud_firestore/cloud_firestore.dart';

class Job {
  final String id;
  final String referenceNo;
  final String driverId;
  final String vehicleId;
  final String loadPort;
  final String unloadPort;
  final String cargoType;
  final String cargoDescription;
  final double cargoWeightKg;
  final double distanceKm;
  final String status; // pending, approved, rejected, completed
  final String? rejectionReason;
  final String createdBy;
  final String companyId;
  final bool softDeleted;
  final List<String>? documents;
  final JobTimestamps timestamps;

  Job({
    required this.id,
    required this.referenceNo,
    required this.driverId,
    required this.vehicleId,
    required this.loadPort,
    required this.unloadPort,
    required this.cargoType,
    required this.cargoDescription,
    required this.cargoWeightKg,
    required this.distanceKm,
    required this.status,
    this.rejectionReason,
    required this.createdBy,
    required this.companyId,
    this.softDeleted = false,
    this.documents,
    required this.timestamps,
  });

  factory Job.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Job.fromMap(data, doc.id);
  }

  factory Job.fromMap(Map<String, dynamic> data, String id) {
    // Nested yapılar için fallback (bazı eski dökümanlar için)
    final route = data['route'] as Map<String, dynamic>?;
    final cargo = data['cargo'] as Map<String, dynamic>?;

    return Job(
      id: id,
      referenceNo: data['referenceNo'] ?? '',
      driverId: data['driverId'] ?? '',
      vehicleId: data['vehicleId'] ?? '',
      loadPort: data['loadPort'] ?? route?['loadPort'] ?? '',
      unloadPort: data['unloadPort'] ?? route?['unloadPort'] ?? '',
      cargoType: data['cargoType'] ?? cargo?['type'] ?? '',
      cargoDescription: data['cargoDescription'] ?? cargo?['description'] ?? '',
      cargoWeightKg: (data['cargoWeightKg'] as num?)?.toDouble() ?? 
                     (cargo?['weightKg'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 
                  (route?['distanceKm'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] ?? 'pending',
      rejectionReason: data['rejectionReason'],
      createdBy: data['createdBy'] ?? '',
      companyId: data['companyId'] ?? '',
      softDeleted: data['softDeleted'] ?? false,
      documents: (data['documents'] as List?)?.map((e) => e.toString()).toList(),
      timestamps: JobTimestamps.fromMap(data['timestamps'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'referenceNo': referenceNo,
      'driverId': driverId,
      'vehicleId': vehicleId,
      'loadPort': loadPort,
      'unloadPort': unloadPort,
      'cargoType': cargoType,
      'cargoDescription': cargoDescription,
      'cargoWeightKg': cargoWeightKg,
      'distanceKm': distanceKm,
      'status': status,
      'rejectionReason': rejectionReason,
      'createdBy': createdBy,
      'companyId': companyId,
      'softDeleted': softDeleted,
      'documents': documents,
      'timestamps': timestamps.toMap(),
    };
  }
}

class JobTimestamps {
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  JobTimestamps({
    this.createdAt,
    this.reviewedAt,
    this.startedAt,
    this.completedAt,
  });

  factory JobTimestamps.fromMap(Map<String, dynamic> map) {
    return JobTimestamps(
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      reviewedAt: (map['reviewedAt'] as Timestamp?)?.toDate(),
      startedAt: (map['startedAt'] as Timestamp?)?.toDate(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }
}

class JobLog {
  final String id;
  final String action;
  final String performedBy;
  final DateTime performedAt;
  final String? note;

  JobLog({
    required this.id,
    required this.action,
    required this.performedBy,
    required this.performedAt,
    this.note,
  });

  factory JobLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JobLog(
      id: doc.id,
      action: data['action'] ?? '',
      performedBy: data['performedBy'] ?? '',
      performedAt: (data['performedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: data['note'],
    );
  }
}

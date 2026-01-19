import 'package:cloud_firestore/cloud_firestore.dart';

class Vehicle {
  final String id;
  final String plate;
  final String companyId;
  final String type;
  final String ownership;
  final String? assignedDriverId;
  final bool isActive;
  final String status; // active, maintenance, out_of_service
  final String? insurancePolicyNumber;
  final DateTime? insuranceExpiryDate;
  final DateTime? lastMaintenanceDate;
  final double? lastMaintenanceKm;
  final double? currentKm;

  Vehicle({
    required this.id,
    required this.plate,
    required this.companyId,
    required this.type,
    required this.ownership,
    this.assignedDriverId,
    this.isActive = true,
    required this.status,
    this.insurancePolicyNumber,
    this.insuranceExpiryDate,
    this.lastMaintenanceDate,
    this.lastMaintenanceKm,
    this.currentKm,
  });

  factory Vehicle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Vehicle(
      id: doc.id,
      plate: data['plate'] ?? '',
      companyId: data['companyId'] ?? '',
      type: data['type'] ?? '',
      ownership: data['ownership'] ?? '',
      assignedDriverId: data['assignedDriverId'],
      isActive: data['isActive'] ?? true,
      status: data['status'] ?? 'active',
      insurancePolicyNumber: data['insurancePolicyNumber'],
      insuranceExpiryDate: (data['insuranceExpiryDate'] as Timestamp?)?.toDate(),
      lastMaintenanceDate: (data['lastMaintenanceDate'] as Timestamp?)?.toDate(),
      lastMaintenanceKm: (data['lastMaintenanceKm'] as num?)?.toDouble(),
      currentKm: (data['currentKm'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'plate': plate,
      'companyId': companyId,
      'type': type,
      'ownership': ownership,
      'assignedDriverId': assignedDriverId,
      'isActive': isActive,
      'status': status,
      'insurancePolicyNumber': insurancePolicyNumber,
      'insuranceExpiryDate': insuranceExpiryDate != null ? Timestamp.fromDate(insuranceExpiryDate!) : null,
      'lastMaintenanceDate': lastMaintenanceDate != null ? Timestamp.fromDate(lastMaintenanceDate!) : null,
      'lastMaintenanceKm': lastMaintenanceKm,
      'currentKm': currentKm,
    };
  }
}

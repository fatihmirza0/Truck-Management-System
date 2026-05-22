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
  final DateTime? insurancePolicyExpiry;
  final double? maintenanceIntervalKm;
  final double? nextMaintenanceKm;
  final String? brandModel;
  final double? modelYear;
  final DateTime? insuranceStartDate;
  final DateTime? mtvPaymentExpiryDate;
  final DateTime? inspectionExpiryDate;
  final DateTime? exhaustEmissionExpiryDate;
  final DateTime? nextMaintenanceDate;
  final DateTime? lastTireChangeDate;
  final double? lastTireChangeKm;
  final double? tireChangeIntervalKm;
  final double? nextTireChangeKm;

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
    this.insurancePolicyExpiry,
    this.maintenanceIntervalKm,
    this.nextMaintenanceKm,
    this.brandModel,
    this.modelYear,
    this.insuranceStartDate,
    this.mtvPaymentExpiryDate,
    this.inspectionExpiryDate,
    this.exhaustEmissionExpiryDate,
    this.nextMaintenanceDate,
    this.lastTireChangeDate,
    this.lastTireChangeKm,
    this.tireChangeIntervalKm,
    this.nextTireChangeKm,
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
      insurancePolicyExpiry: (data['insurancePolicyExpiry'] as Timestamp?)?.toDate(),
      maintenanceIntervalKm: (data['maintenanceIntervalKm'] as num?)?.toDouble(),
      nextMaintenanceKm: (data['nextMaintenanceKm'] as num?)?.toDouble(),
      brandModel: data['brandModel'],
      modelYear: (data['modelYear'] as num?)?.toDouble(),
      insuranceStartDate: (data['insuranceStartDate'] as Timestamp?)?.toDate(),
      mtvPaymentExpiryDate: (data['mtvPaymentExpiryDate'] as Timestamp?)?.toDate(),
      inspectionExpiryDate: (data['inspectionExpiryDate'] as Timestamp?)?.toDate(),
      exhaustEmissionExpiryDate: (data['exhaustEmissionExpiryDate'] as Timestamp?)?.toDate(),
      nextMaintenanceDate: (data['nextMaintenanceDate'] as Timestamp?)?.toDate(),
      lastTireChangeDate: (data['lastTireChangeDate'] as Timestamp?)?.toDate(),
      lastTireChangeKm: (data['lastTireChangeKm'] as num?)?.toDouble(),
      tireChangeIntervalKm: (data['tireChangeIntervalKm'] as num?)?.toDouble(),
      nextTireChangeKm: (data['nextTireChangeKm'] as num?)?.toDouble(),
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
      'insurancePolicyExpiry': insurancePolicyExpiry != null ? Timestamp.fromDate(insurancePolicyExpiry!) : null,
      'maintenanceIntervalKm': maintenanceIntervalKm,
      'nextMaintenanceKm': nextMaintenanceKm,
      'brandModel': brandModel,
      'modelYear': modelYear,
      'insuranceStartDate': insuranceStartDate != null ? Timestamp.fromDate(insuranceStartDate!) : null,
      'mtvPaymentExpiryDate': mtvPaymentExpiryDate != null ? Timestamp.fromDate(mtvPaymentExpiryDate!) : null,
      'inspectionExpiryDate': inspectionExpiryDate != null ? Timestamp.fromDate(inspectionExpiryDate!) : null,
      'exhaustEmissionExpiryDate': exhaustEmissionExpiryDate != null ? Timestamp.fromDate(exhaustEmissionExpiryDate!) : null,
      'nextMaintenanceDate': nextMaintenanceDate != null ? Timestamp.fromDate(nextMaintenanceDate!) : null,
      'lastTireChangeDate': lastTireChangeDate != null ? Timestamp.fromDate(lastTireChangeDate!) : null,
      'lastTireChangeKm': lastTireChangeKm,
      'tireChangeIntervalKm': tireChangeIntervalKm,
      'nextTireChangeKm': nextTireChangeKm,
    };
  }
}

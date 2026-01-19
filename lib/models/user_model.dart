import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String companyId;
  final bool isActive;
  final bool softDeleted;
  final List<String> permissions;
  final String? plateNumber;
  final String? activePlate;
  final String? fcmToken;
  final DateTime? lastLoginAt;
  final String? jobStatus; // available, busy, on_trip

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.companyId,
    this.isActive = true,
    this.softDeleted = false,
    this.permissions = const [],
    this.plateNumber,
    this.activePlate,
    this.fcmToken,
    this.lastLoginAt,
    this.jobStatus,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'driver',
      companyId: data['companyId'] ?? '',
      isActive: data['isActive'] ?? true,
      softDeleted: data['softDeleted'] ?? false,
      permissions: List<String>.from(data['permissions'] ?? []),
      plateNumber: data['plateNumber'],
      activePlate: data['activePlate'],
      fcmToken: data['fcmToken'],
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
      jobStatus: data['jobStatus'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'companyId': companyId,
      'isActive': isActive,
      'softDeleted': softDeleted,
      'permissions': permissions,
      'plateNumber': plateNumber,
      'activePlate': activePlate,
      'fcmToken': fcmToken,
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'jobStatus': jobStatus,
    };
  }

  AppUser copyWith({
    String? name,
    String? email,
    String? phone,
    String? role,
    String? companyId,
    bool? isActive,
    bool? softDeleted,
    List<String>? permissions,
    String? plateNumber,
    String? activePlate,
    String? fcmToken,
    DateTime? lastLoginAt,
    String? jobStatus,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      companyId: companyId ?? this.companyId,
      isActive: isActive ?? this.isActive,
      softDeleted: softDeleted ?? this.softDeleted,
      permissions: permissions ?? this.permissions,
      plateNumber: plateNumber ?? this.plateNumber,
      activePlate: activePlate ?? this.activePlate,
      fcmToken: fcmToken ?? this.fcmToken,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      jobStatus: jobStatus ?? this.jobStatus,
    );
  }
}

import 'dart:convert';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import '../models/user_model.dart';
import '../models/job_model.dart';
import '../models/vehicle_model.dart';
import '../config/app_config.dart';

class FirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // static final _functions = FirebaseFunctions.instance;

  static Future<Map<String, String>> _headers() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Not logged in");

    final token = await user.getIdToken(true);
    return {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    };
  }

  // ============================================
  // CONSTANTS
  // ============================================

  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';
  static const String statusCompleted = 'completed';

  // ============================================
  // AUTHENTICATION & CURRENT USER
  // ============================================

  /// Get current user UID
  static String? get currentUserUid => _auth.currentUser?.uid;

  /// Get current user role
  static Future<String?> getCurrentUserRole() async {
    final uid = currentUserUid;
    if (uid == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return doc.data()?['role'];
    } catch (e) {
      print('Get current user role error: $e');
      return null;
    }
  }

  /// Get current user data
  static Future<AppUser?> getCurrentUserData() async {
    final uid = currentUserUid;
    if (uid == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc);
    } catch (e) {
      debugPrint('Get current user data error: $e');
      return null;
    }
  }

  // 🔥 SAAS HELPER - Use local cache from AuthService for reliability and speed
  static Future<String?> getCompanyId() async {
    return await AuthService.getCompanyId();
  }

  // ============================================
  // USER OPERATIONS
  // ============================================
  static Future<void> createDriverHttp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String plate,
  }) async {
    final res = await http.post(
      Uri.parse(AppConfig.createDriverUrl),
      headers: await _headers(),
      body: jsonEncode({
        "name": name,
        "email": email,
        "password": password,
        "phone": phone,
        "plate": plate,
        "jobStatus": "available", // 🔥 EKLE
      }),
    );

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }
  }

  static Future<void> createUserHttp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
    String? plate,
  }) async {
    final res = await http.post(
      Uri.parse(AppConfig.createUserUrl),
      headers: await _headers(),
      body: jsonEncode({
        "name": name,
        "email": email,
        "password": password,
        "phone": phone,
        "role": role,
        "plate": plate,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }
  }

  static Future<void> updateUserHttp({
    required String uid,
    required String name,
    required String email,
    required String phone,
    required String role,
    String? plate,
  }) async {
    final res = await http.post(
      Uri.parse(AppConfig.updateUserUrl),
      headers: await _headers(),
      body: jsonEncode({
        "uid": uid,
        "name": name,
        "email": email,
        "phone": phone,
        "role": role,
        "plate": plate,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }
  }

  static Future<void> softDeleteUserHttp(String userId) async {
    final res = await http.post(
      Uri.parse(AppConfig.softDeleteUserUrl),
      headers: await _headers(),
      body: jsonEncode({"userId": userId}),
    );

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }
  }
  static Future<String> getDriverStatus(String driverId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(driverId)
        .get();

    return doc.data()?['jobStatus'] ?? 'available';
  }

  /// Get user data by UID with company scoping
  static Future<AppUser?> getUserData(String uid) async {
    try {
      final companyId = await getCompanyId();
      if (companyId == null) return null;

      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      
      final user = AppUser.fromFirestore(doc);
      if (user.companyId != companyId) return null; // 🔥 Security Check
      
      return user;
    } catch (e) {
      debugPrint('Get user data error: $e');
      return null;
    }
  }

  /// Fetch all active drivers
  static Future<List<AppUser>> fetchDrivers() async {
    try {
      final companyId = await getCompanyId();
      if (companyId == null) return [];

      final snap = await _firestore
          .collection('users')
          .where('companyId', isEqualTo: companyId) // 🔥 SAAS
          .where('role', isEqualTo: 'driver')
          .where('softDeleted', isEqualTo: false)
          .where('isActive', isEqualTo: true)
          .get();

      return snap.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Fetch drivers error: $e');
      return [];
    }
  }

  /// Fetch all users (for reports)
  static Future<List<AppUser>> fetchAllUsers() async {
    try {
      final companyId = await getCompanyId();
      if (companyId == null) return [];

      final snap = await _firestore
          .collection("users")
          .where('companyId', isEqualTo: companyId) // 🔥 SAAS
          .where("softDeleted", isEqualTo: false)
          .get();
      return snap.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Fetch all users error: $e');
      return [];
    }
  }

  /// Stream users with vehicle info
  static Stream<List<Map<String, dynamic>>> streamUsersWithVehicle(
      String role) async* {
    
    final companyId = await getCompanyId();
    if (companyId == null) yield* Stream.empty();
    
    final usersStream = _firestore
        .collection("users")
        .where('companyId', isEqualTo: companyId) // 🔥 SAAS
        .where("role", isEqualTo: role)
        .where("softDeleted", isEqualTo: false)
        .snapshots();

    await for (final userSnap in usersStream) {
      final users = userSnap.docs;
      final driverIds = users.map((u) => u.id).toList();
      final Map<String, String> plateMap = {};

      if (role == "driver" && driverIds.isNotEmpty) {
        // Handle Firestore whereIn limit (10 items)
        final chunks = <List<String>>[];
        for (var i = 0; i < driverIds.length; i += 10) {
          chunks.add(
            driverIds.sublist(
              i,
              i + 10 > driverIds.length ? driverIds.length : i + 10,
            ),
          );
        }

        for (final chunk in chunks) {
          try {
            final vehicleSnap = await _firestore
                .collection("vehicles")
                .where("companyId", isEqualTo: companyId) // 🔥 SAAS
                .where("assignedDriverId", whereIn: chunk)
                .get();

            for (final v in vehicleSnap.docs) {
              plateMap[v["assignedDriverId"]] = v["plate"];
            }
          } catch (e) {
            print('Stream users with vehicle error: $e');
          }
        }
      }

      yield users.map((u) {
        final data = u.data();
        return {
          "uid": u.id,
          "name": data["name"] ?? "",
          "email": data["email"] ?? "",
          "phone": data["phone"] ?? "",
          "role": data["role"],
          "plateNumber": plateMap[u.id] ?? "",
        };
      }).toList();
    }
  }

  // ============================================
  // VEHICLE OPERATIONS
  // ============================================

  /// Get vehicle data by vehicleId with company scoping
  static Future<Vehicle?> getVehicleData(String vehicleId) async {
    try {
      final companyId = await getCompanyId();
      if (companyId == null) return null;

      final doc = await _firestore.collection('vehicles').doc(vehicleId).get();
      if (!doc.exists) return null;
      
      final vehicle = Vehicle.fromFirestore(doc);
      if (vehicle.companyId != companyId) return null; // 🔥 Security Check
      
      return vehicle;
    } catch (e) {
      debugPrint('Get vehicle data error: $e');
      return null;
    }
  }

  /// Fetch all active vehicles
  static Future<List<Vehicle>> fetchVehicles() async {
    try {
      final companyId = await getCompanyId();
      if (companyId == null) return [];

      final snap = await _firestore
          .collection('vehicles')
          .where('companyId', isEqualTo: companyId) // 🔥 SAAS
          .where('isActive', isEqualTo: true)
          .get();

      return snap.docs.map((doc) => Vehicle.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Fetch vehicles error: $e');
      return [];
    }
  }

  /// Fetch all vehicles (for reports)
  static Future<List<Vehicle>> fetchAllVehicles() async {
    try {
      final companyId = await getCompanyId();
      if (companyId == null) return [];

      final snap = await _firestore
          .collection('vehicles')
          .where('companyId', isEqualTo: companyId)
          .get();

      return snap.docs.map((doc) => Vehicle.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Fetch all vehicles error: $e');
      return [];
    }
  }

  /// Fetch vehicles assigned to a specific driver
  static Future<List<Vehicle>> fetchVehiclesByDriver(
      String driverId) async {
    try {
      final companyId = await getCompanyId();
      if (companyId == null) return [];

      final snap = await _firestore
          .collection('vehicles')
          .where('companyId', isEqualTo: companyId) // 🔥 SAAS
          .where('assignedDriverId', isEqualTo: driverId)
          .where('isActive', isEqualTo: true)
          .get();

      return snap.docs.map((doc) => Vehicle.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Fetch vehicles by driver error: $e');
      return [];
    }
  }

  /// Create a new vehicle
  static Future<String> createVehicle({
    required String plate,
    required String type,
    required String ownership,
    String? assignedDriverId,
    String status = 'active', // active, maintenance, out_of_service
    String? insurancePolicyNumber,
    DateTime? insuranceExpiryDate,
    DateTime? lastMaintenanceDate,
    double? lastMaintenanceKm,
    double? currentKm,
  }) async {
    final companyId = await getCompanyId(); // 🔥 SAAS
    if (companyId == null) throw Exception('Company ID bulunamadı');

    try {
      final vehicleRef = await _firestore.collection('vehicles').add({
        'plate': plate.trim().toUpperCase(),
        'companyId': companyId, // 🔥 SAAS
        'type': type,
        'ownership': ownership,
        'assignedDriverId': assignedDriverId,
        'isActive': true,
        'status': status,
        'insurancePolicyNumber': insurancePolicyNumber,
        'insuranceExpiryDate': insuranceExpiryDate != null ? Timestamp.fromDate(insuranceExpiryDate) : null,
        'lastMaintenanceDate': lastMaintenanceDate != null ? Timestamp.fromDate(lastMaintenanceDate) : null,
        'lastMaintenanceKm': lastMaintenanceKm,
        'currentKm': currentKm,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return vehicleRef.id;
    } catch (e) {
      print('Create vehicle error: $e');
      rethrow;
    }
  }

  /// Update vehicle details
  static Future<void> updateVehicle({
    required String vehicleId,
    required String plate,
    required String type,
    required String ownership,
    String? assignedDriverId,
    String status = 'active',
    String? insurancePolicyNumber,
    DateTime? insuranceExpiryDate,
    DateTime? lastMaintenanceDate,
    double? lastMaintenanceKm,
    double? currentKm,
  }) async {
    try {
      await _firestore.collection('vehicles').doc(vehicleId).update({
        'plate': plate.trim().toUpperCase(),
        'type': type,
        'ownership': ownership,
        'assignedDriverId': assignedDriverId,
        'status': status,
        'insurancePolicyNumber': insurancePolicyNumber,
        'insuranceExpiryDate': insuranceExpiryDate != null ? Timestamp.fromDate(insuranceExpiryDate) : null,
        'lastMaintenanceDate': lastMaintenanceDate != null ? Timestamp.fromDate(lastMaintenanceDate) : null,
        'lastMaintenanceKm': lastMaintenanceKm,
        'currentKm': currentKm,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Update vehicle error: $e');
      rethrow;
    }
  }

  /// Assign driver to vehicle
  static Future<void> assignDriverToVehicle(
      String vehicleId, String driverId) async {
    try {
      await _firestore.collection('vehicles').doc(vehicleId).update({
        'assignedDriverId': driverId,
      });
    } catch (e) {
      print('Assign driver to vehicle error: $e');
      rethrow;
    }
  }

  /// Unassign driver from vehicle
  static Future<void> unassignDriverFromVehicle(String vehicleId) async {
    try {
      await _firestore.collection('vehicles').doc(vehicleId).update({
        'assignedDriverId': null,
      });
    } catch (e) {
      print('Unassign driver from vehicle error: $e');
      rethrow;
    }
  }

  /// Update vehicle status
  static Future<void> updateVehicleStatus(
      String vehicleId, bool isActive) async {
    try {
      await _firestore.collection('vehicles').doc(vehicleId).update({
        'isActive': isActive,
      });
    } catch (e) {
      print('Update vehicle status error: $e');
      rethrow;
    }
  }

  // ============================================
  // JOB OPERATIONS
  // ============================================

  /// Create a new job (HTTP)
  static Future<String> createJob({
    required String driverId,
    required String vehicleId,
    required String loadPort,
    required String unloadPort,
    required String cargoType,
    required String cargoDescription,
    required double cargoWeightKg,
    required double distanceKm,
  }) async {
    final res = await http.post(
      Uri.parse(AppConfig.createJobUrl),
      headers: await _headers(),
      body: jsonEncode({
        "driverId": driverId,
        "vehicleId": vehicleId,
        "loadPort": loadPort,
        "unloadPort": unloadPort,
        "cargoType": cargoType,
        "cargoDescription": cargoDescription,
        "cargoWeightKg": cargoWeightKg,
        "distanceKm": distanceKm,
      }),
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['error'] ?? "Job creation failed");
    }

    final data = jsonDecode(res.body);
    return data['jobId'];
  }

  /// Update job status to approved
  static Future<void> approveJob(String jobId) async {
    try {
      final currentUid = currentUserUid;
      if (currentUid == null) return;

      final batch = _firestore.batch();
      final jobRef = _firestore.collection('jobs').doc(jobId);

      batch.update(jobRef, {
        'status': statusApproved,
        'timestamps.reviewedAt': FieldValue.serverTimestamp(),
      });

      final logRef = jobRef.collection('logs').doc();
      batch.set(logRef, {
        'action': 'approved',
        'performedBy': currentUid,
        'performedAt': FieldValue.serverTimestamp(),
        'note': null,
      });

      await batch.commit();
    } catch (e) {
      print('Approve job error: $e');
      rethrow;
    }
  }

  /// Update job status to rejected
  static Future<void> rejectJob(String jobId, String reason) async {
    try {
      final currentUid = currentUserUid;
      if (currentUid == null) return;

      final batch = _firestore.batch();
      final jobRef = _firestore.collection('jobs').doc(jobId);

      batch.update(jobRef, {
        'status': statusRejected,
        'rejectionReason': reason.trim(),
        'timestamps.reviewedAt': FieldValue.serverTimestamp(),
      });

      final logRef = jobRef.collection('logs').doc();
      batch.set(logRef, {
        'action': 'rejected',
        'performedBy': currentUid,
        'performedAt': FieldValue.serverTimestamp(),
        'note': reason.trim(),
      });

      await batch.commit();
    } catch (e) {
      print('Reject job error: $e');
      rethrow;
    }
  }

  /// Update job status to completed
  static Future<void> completeJob(String jobId) async {
    try {
      final currentUid = currentUserUid;
      if (currentUid == null) return;

      final batch = _firestore.batch();
      final jobRef = _firestore.collection('jobs').doc(jobId);

      batch.update(jobRef, {
        'status': statusCompleted,
      });

      final logRef = jobRef.collection('logs').doc();
      batch.set(logRef, {
        'action': 'completed',
        'performedBy': currentUid,
        'performedAt': FieldValue.serverTimestamp(),
        'note': null,
      });

      await batch.commit();
    } catch (e) {
      print('Complete job error: $e');
      rethrow;
    }
  }

  /// Soft delete a job
  static Future<void> deleteJob(String jobId) async {
    try {
      await _firestore.collection('jobs').doc(jobId).update({
        'softDeleted': true,
      });
    } catch (e) {
      print('Delete job error: $e');
      rethrow;
    }
  }

  /// Get job details with company scoping
  static Future<Job?> getJobDetails(String jobId) async {
    try {
      final companyId = await getCompanyId();
      if (companyId == null) return null;

      final doc = await _firestore.collection('jobs').doc(jobId).get();
      if (!doc.exists) return null;
      
      final job = Job.fromFirestore(doc);
      if (job.companyId != companyId) return null; // 🔥 Security Check
      
      return job;
    } catch (e) {
      debugPrint('Get job details error: $e');
      return null;
    }
  }

  /// Fetch all jobs (for reports)
  static Future<List<Job>> fetchAllJobs() async {
    final companyId = await getCompanyId();
    if (companyId == null) return [];

    final snap = await FirebaseFirestore.instance
        .collection("jobs")
        .where('companyId', isEqualTo: companyId) // 🔥 SAAS
        .where("softDeleted", isEqualTo: false)
        .get();

    return snap.docs.map((doc) => Job.fromFirestore(doc)).toList();
  }

  /// Stream job logs
  static Stream<QuerySnapshot> getJobLogs(String jobId) {
    try {
      return _firestore
          .collection('jobs')
          .doc(jobId)
          .collection('logs')
          .orderBy('performedAt', descending: true)
          .snapshots();
    } catch (e) {
      print('Get job logs error: $e');
      return const Stream.empty();
    }
  }

  /// Consolidated stream for jobs based on role and status
  static Stream<List<Job>> getJobsStream({
    required String status,
  }) async* {
    final companyId = await getCompanyId();
    if (companyId == null) {
      yield [];
      return;
    }

    final role = await AuthService.getSavedUserRole(); // 🔥 Use AuthService
    final uid = currentUserUid;

    Query<Map<String, dynamic>> query = _firestore
        .collection('jobs')
        .where('companyId', isEqualTo: companyId) // 🔥 SAAS
        .where('softDeleted', isEqualTo: false)
        .where('status', isEqualTo: status);

    // 🔥 Role-based filtering
    if (role == 'dispatch' && uid != null) {
      query = query.where('createdBy', isEqualTo: uid);
    } else if (role == 'driver' && uid != null) {
      query = query.where('driverId', isEqualTo: uid);
    }

    yield* query
        .orderBy('timestamps.createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Job.fromFirestore(doc)).toList());
  }


  // ============================================
  // CACHE HELPERS
  // ============================================

  /// Build user cache map (returns name by uid)
  static Future<Map<String, String>> fetchDriverCache() async {
    try {
      final companyId = await getCompanyId();
      if (companyId == null) return {};

      final users = await _firestore
          .collection('users')
          .where('companyId', isEqualTo: companyId) // 🔥 SAAS
          .where('role', isEqualTo: 'driver')
          .where('softDeleted', isEqualTo: false)
          .where('isActive', isEqualTo: true)
          .get();

      final cache = <String, String>{};
      for (var doc in users.docs) {
        final data = doc.data();
        cache[doc.id] = data['name'] ?? 'Bilinmiyor';
      }
      return cache;
    } catch (e) {
      print('Fetch driver cache error: $e');
      return {};
    }
  }

  /// Build vehicle cache map (returns plate by vehicleId)
  static Future<Map<String, String>> fetchVehicleCache() async {
    try {
      final companyId = await getCompanyId();
      if (companyId == null) return {};

      final vehicles = await _firestore
          .collection('vehicles')
          .where('companyId', isEqualTo: companyId) // 🔥 SAAS
          .where('isActive', isEqualTo: true)
          .get();

      final cache = <String, String>{};
      for (var doc in vehicles.docs) {
        final data = doc.data();
        cache[doc.id] = data['plate'] ?? 'Bilinmiyor';
      }
      return cache;
    } catch (e) {
      print('Fetch vehicle cache error: $e');
      return {};
    }
  }

  /// Fetch user and plate cache (legacy method for compatibility)
  static Future<Map<String, Map<String, String>>> fetchUserCache() async {
    try {
      final companyId = await getCompanyId();
      if (companyId == null) return {"users": {}, "plates": {}};

      final usersSnap = await _firestore
          .collection("users")
          .where('companyId', isEqualTo: companyId) // 🔥 SAAS
          .where("softDeleted", isEqualTo: false)
          .get();

      final userMap = <String, String>{};
      final plateMap = <String, String>{};

      for (final u in usersSnap.docs) {
        userMap[u.id] = u["name"] ?? "-";
      }

      final vehicleSnap = await _firestore
          .collection("vehicles")
          .where('companyId', isEqualTo: companyId) // 🔥 SAAS
          .where('isActive', isEqualTo: true)
          .get();

      for (final v in vehicleSnap.docs) {
        final assignedDriverId = v["assignedDriverId"];
        if (assignedDriverId != null) {
          plateMap[assignedDriverId] = v["plate"] ?? "-";
        }
      }

      return {
        "users": userMap,
        "plates": plateMap,
      };
    } catch (e) {
      print('Fetch user cache error: $e');
      return {"users": {}, "plates": {}};
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Status renkleri
  static Color getStatusColor(String status) {
    switch (status) {
      case statusPending:
        return const Color(0xFFF59E0B); // Amber
      case statusApproved:
        return const Color(0xFF10B981); // Emerald
      case statusRejected:
        return const Color(0xFFEF4444); // Red
      case statusCompleted:
        return const Color(0xFF8B5CF6); // Violet
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  /// Status metinleri
  static String getStatusText(String status) {
    switch (status) {
      case statusPending:
        return "Bekliyor";
      case statusApproved:
        return "Yolda";
      case statusRejected:
        return "Reddedildi";
      case statusCompleted:
        return "Tamamlandı";
      default:
        return "Bilinmiyor";
    }
  }

  // ============================================
  // LOGGING SYSTEM
  // ============================================

  /// Create a log entry (global logs collection)
  static Future<void> createLog({
    required String action,
    String? jobId,
    required String actorId,
  }) async {
    try {
      final companyId = await getCompanyId();
      if (companyId == null) return;

      await _firestore.collection("logs").add({
        "action": action,
        "jobId": jobId,
        "actorId": actorId,
        "companyId": companyId, // 🔥 SAAS
        "createdAt": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Create log error: $e');
    }
  }
  static Future<void> updateDriverStatus(String driverUid, String status) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(driverUid)
        .update({'jobStatus': status});
  }
}

import 'dart:convert';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class FirestoreService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static const _baseUrl =
      "https://us-central1-truck-dispatch-system.cloudfunctions.net";
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
  static Future<Map<String, dynamic>?> getCurrentUserData() async {
    final uid = currentUserUid;
    if (uid == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      print('Get current user data error: $e');
      return null;
    }
  }

  // 🔥 SAAS HELPER
  static Future<String?> getCompanyId() async {
    final userData = await getCurrentUserData();
    return userData?['companyId'];
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
      Uri.parse("$_baseUrl/createDriverHttp"),
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
      Uri.parse("$_baseUrl/createUserHttp"),
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
      Uri.parse("$_baseUrl/updateUserHttp"),
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
      Uri.parse("$_baseUrl/softDeleteUserHttp"),
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

  // ============================================
  // JOB OPERATIONS (HTTP)
  // ============================================

  static Future<void> jobActionHttp({
    required String jobId,
    required String action, // approve | reject | complete
    String? reason,
  }) async {
    final res = await http.post(
      Uri.parse("$_baseUrl/jobActionHttp"),
      headers: await _headers(),
      body: jsonEncode({
        "jobId": jobId,
        "action": action,
        "reason": reason,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }
  }

  /// Get user data by UID
  static Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      print('Get user data error: $e');
      return null;
    }
  }

  /// Fetch all active drivers
  static Future<List<Map<String, dynamic>>> fetchDrivers() async {
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

      return snap.docs.map((doc) {
        final d = doc.data();
        return {
          'uid': doc.id,
          'name': d['name'] ?? '-',
          'email': d['email'] ?? '-',
          'phone': d['phone'] ?? '-',
          'jobStatus': d['jobStatus'] ?? 'available', // 🔥
          'activePlate': d['activePlate'],             // 🔥
        };
      }).toList();
    } catch (e) {
      print('Fetch drivers error: $e');
      return [];
    }
  }

  /// Fetch all users (for reports)
  static Future<List<DocumentSnapshot>> fetchAllUsers() async {
    try {
      final companyId = await getCompanyId();
      if (companyId == null) return [];

      final snap = await _firestore
          .collection("users")
          .where('companyId', isEqualTo: companyId) // 🔥 SAAS
          .where("softDeleted", isEqualTo: false,)
          .get();
      return snap.docs;
    } catch (e) {
      print('Fetch all users error: $e');
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

  /// Get vehicle data by vehicleId
  static Future<Map<String, dynamic>?> getVehicleData(String vehicleId) async {
    try {
      final doc = await _firestore.collection('vehicles').doc(vehicleId).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      print('Get vehicle data error: $e');
      return null;
    }
  }

  /// Fetch all active vehicles
  static Future<List<Map<String, dynamic>>> fetchVehicles() async {
    try {
      final companyId = await getCompanyId();
      if (companyId == null) return [];

      final snap = await _firestore
          .collection('vehicles')
          .where('companyId', isEqualTo: companyId) // 🔥 SAAS
          .where('isActive', isEqualTo: true)
          .get();

      return snap.docs.map((doc) {
        final d = doc.data();
        return {
          'vehicleId': doc.id,
          'plate': d['plate'] ?? '-',
          'type': d['type'] ?? '-',
          'ownership': d['ownership'] ?? '-',
          'assignedDriverId': d['assignedDriverId'],
          'isActive': d['isActive'] ?? true,
          'status': d['status'],
          'insurancePolicyNumber': d['insurancePolicyNumber'],
          'insuranceExpiryDate': d['insuranceExpiryDate'],
          'lastMaintenanceDate': d['lastMaintenanceDate'],
          'lastMaintenanceKm': d['lastMaintenanceKm'],
          'currentKm': d['currentKm'],
        };
      }).toList();
    } catch (e) {
      print('Fetch vehicles error: $e');
      return [];
    }
  }

  /// Fetch vehicles assigned to a specific driver
  static Future<List<Map<String, dynamic>>> fetchVehiclesByDriver(
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

      return snap.docs.map((doc) {
        final d = doc.data();
        return {
          'vehicleId': doc.id,
          'plate': d['plate'] ?? '-',
          'type': d['type'] ?? '-',
          'ownership': d['ownership'] ?? '-',
        };
      }).toList();
    } catch (e) {
      print('Fetch vehicles by driver error: $e');
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
      Uri.parse("$_baseUrl/createJobHttp"),
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

  /// Get job details
  static Future<Map<String, dynamic>?> getJobDetails(String jobId) async {
    try {
      final doc = await _firestore.collection('jobs').doc(jobId).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      print('Get job details error: $e');
      return null;
    }
  }

  /// Fetch all jobs (for reports)
  static Future<List<DocumentSnapshot>> fetchAllJobs() async {
    final companyId = await getCompanyId();
    if (companyId == null) return [];

    final snap = await FirebaseFirestore.instance
        .collection("jobs")
        .where('companyId', isEqualTo: companyId) // 🔥 SAAS
        .where("softDeleted", isEqualTo: false)
        .get();

    return snap.docs;
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

  /// Stream jobs by status
  static Stream<QuerySnapshot> getJobsByStatus(String status) async* {
    final companyId = await getCompanyId();
    if (companyId == null) yield* Stream.empty();

    try {
      final role = await AuthService.getSavedUserRole(); // 🔥 Check Role
      final uid = currentUserUid; // Need UID for filter

      var query = _firestore
          .collection('jobs')
          .where('companyId', isEqualTo: companyId) // 🔥 SAAS
          .where('softDeleted', isEqualTo: false)
          .where('status', isEqualTo: status);

      // 🔥 Restricted Access for Dispatch
      if (role == 'dispatch' && uid != null) {
        query = query.where('createdBy', isEqualTo: uid);
      }

      yield* query
          .orderBy('timestamps.createdAt', descending: true)
          .snapshots();
    } catch (e) {
      print('Get jobs by status error: $e');
      yield* Stream.empty();
    }
  }

  /// Stream jobs by dispatch user
  static Stream<QuerySnapshot<Map<String, dynamic>>> getDispatchJobsStream({
    required String userId,
    required String status,
  }) async* {
    final companyId = await getCompanyId();
    if (companyId == null) yield* Stream.empty();

    try {
      yield* _firestore
          .collection("jobs")
          .where('companyId', isEqualTo: companyId) // 🔥 SAAS
          .where("createdBy", isEqualTo: userId)
          .where("status", isEqualTo: status)
          .where("softDeleted", isEqualTo: false)
          .orderBy("timestamps.createdAt", descending: true)
          .snapshots();
    } catch (e) {
      print('Get dispatch jobs stream error: $e');
      yield* Stream.empty();
    }
  }

  /// Alternative method for compatibility
  static Stream<QuerySnapshot> getDispatchJobs(String userId, String status) async* {
    final companyId = await getCompanyId();
    if (companyId == null) yield* Stream.empty();

    try {
      yield* _firestore
          .collection('jobs')
          .where('companyId', isEqualTo: companyId) // 🔥 SAAS
          .where('createdBy', isEqualTo: userId)
          .where('status', isEqualTo: status)
          .where('softDeleted', isEqualTo: false)
          .orderBy('timestamps.createdAt', descending: true)
          .snapshots();
    } catch (e) {
      print('Get dispatch jobs error: $e');
      yield* Stream.empty();
    }
  }

  /// Stream jobs by driver
  static Stream<QuerySnapshot> getDriverJobs(String driverId, String status) async* {
    final companyId = await getCompanyId();
    if (companyId == null) yield* Stream.empty();

    try {
      yield* _firestore
          .collection('jobs')
          .where('companyId', isEqualTo: companyId) // 🔥 SAAS
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: status)
          .where('softDeleted', isEqualTo: false)
          .orderBy('timestamps.createdAt', descending: true)
          .snapshots();
    } catch (e) {
      print('Get driver jobs error: $e');
      yield* Stream.empty();
    }
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
      await _firestore.collection("logs").add({
        "action": action,
        "jobId": jobId,
        "actorId": actorId,
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

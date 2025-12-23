import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_Service.dart';

class JobLookups {
  final Map<String, String> userNames;
  final Map<String, String> vehiclePlates;

  const JobLookups({
    required this.userNames,
    required this.vehiclePlates,
  });

  factory JobLookups.empty() => const JobLookups(
        userNames: {},
        vehiclePlates: {},
      );

  String userName(String? uid) {
    if (uid == null) return "-";
    return userNames[uid] ?? "-";
  }

  String vehiclePlate(String? vehicleId) {
    if (vehicleId == null) return "-";
    return vehiclePlates[vehicleId] ?? "-";
  }

  static Future<JobLookups> build(FirebaseFirestore firestore) async {
    final userSnap = await firestore
        .collection("users")
        .where("softDeleted", isEqualTo: false)
        .get();

    final vehicleSnap = await firestore
        .collection("vehicles")
        .where("isActive", isEqualTo: true)
        .get();

    return JobLookups(
      userNames: {
        for (final doc in userSnap.docs) doc.id: doc.data()["name"] ?? "-",
      },
      vehiclePlates: {
        for (final doc in vehicleSnap.docs) doc.id: doc.data()["plate"] ?? "-",
      },
    );
  }
}

class JobRecord {
  final String id;
  final Map<String, dynamic> data;

  JobRecord({required this.id, required this.data});

  factory JobRecord.fromSnapshot(
      QueryDocumentSnapshot<Map<String, dynamic>> snapshot) {
    return JobRecord(
      id: snapshot.id,
      data: snapshot.data(),
    );
  }

  String get referenceNo => (data["referenceNo"] ?? "") as String;
  String? get driverId => data["driverId"] as String?;
  String? get vehicleId => data["vehicleId"] as String?;
  String? get createdBy => data["createdBy"] as String?;
  String get status => (data["status"] ?? "") as String;
  Map<String, dynamic>? get cargo => data["cargo"] as Map<String, dynamic>?;
  Map<String, dynamic>? get route => data["route"] as Map<String, dynamic>?;
  Map<String, dynamic>? get timestamps =>
      data["timestamps"] as Map<String, dynamic>?;
  Timestamp? get createdAt => timestamps?["createdAt"] as Timestamp?;
  String? get rejectionReason => data["rejectionReason"] as String?;
  List<String> get documents {
    final docs = data["documents"] as List<dynamic>?;
    return docs?.map((e) => e.toString()).toList() ?? const [];
  }
  String? get deliveryProof => data["deliveryProof"] as String?;
}

class JobService {
  JobService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<JobLookups> loadLookups() async {
    return JobLookups.build(_firestore);
  }

  static Stream<List<JobRecord>> streamJobsByStatus(String status) {
    return FirestoreService.getJobsByStatus(status).map(
      (snapshot) =>
          snapshot.docs.map((doc) => JobRecord.fromSnapshot(doc)).toList(),
    );
  }

  static Future<void> approveJob(String jobId) async {
    await FirestoreService.jobActionHttp(jobId: jobId, action: 'approve');
  }

  static Future<void> rejectJob(String jobId, String reason) async {
    await FirestoreService.jobActionHttp(
      jobId: jobId,
      action: 'reject',
      reason: reason,
    );
  }

  static Future<void> completeJob(String jobId, {String? deliveryProofUrl}) async {
    if (deliveryProofUrl != null) {
      await _firestore.collection("jobs").doc(jobId).update({
        "deliveryProof": deliveryProofUrl,
      });
    }

    await FirestoreService.jobActionHttp(
      jobId: jobId,
      action: 'complete',
    );
  }

  static Future<void> deleteJob(String jobId) {
    return FirestoreService.deleteJob(jobId);
  }

  static Future<Map<String, dynamic>?> getJobDetails(String jobId) {
    return FirestoreService.getJobDetails(jobId);
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getJobLogs(String jobId) {
    return FirestoreService.getJobLogs(jobId);
  }
}

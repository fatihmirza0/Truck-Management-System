import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JobService {
  static final _firestore = FirebaseFirestore.instance;

  static Future<void> _update(String id, Map<String, dynamic> data) async {
    await _firestore.collection("jobs").doc(id).update(data);
  }

  static Future<void> _addLog(
      String jobId,
      String action,
      String? note,
      ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await _firestore
        .collection("jobs")
        .doc(jobId)
        .collection("logs")
        .add({
      "action": action,
      "performedBy": uid,
      "performedAt": FieldValue.serverTimestamp(),
      "note": note,
    });
  }

  static Future<void> approveJob(String jobId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("Not authenticated");

    final ref = FirebaseFirestore.instance.collection("jobs").doc(jobId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception("Job not found");
      }

      final data = snap.data()!;
      final status = data["status"];

      // 🔐 KİLİT
      if (status != "pending") {
        throw Exception("Job already processed");
      }

      tx.update(ref, {
        "status": "approved",
        "timestamps.reviewedAt": FieldValue.serverTimestamp(),
        "reviewedBy": uid,
      });
    });

    await _addLog(jobId, "approved", null);
  }

  static Future<void> rejectJob(String jobId, String reason) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("Not authenticated");

    final ref = FirebaseFirestore.instance.collection("jobs").doc(jobId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception("Job not found");
      }

      final data = snap.data()!;
      final status = data["status"];

      // 🔐 KİLİT
      if (status != "pending") {
        throw Exception("Job already processed");
      }

      tx.update(ref, {
        "status": "rejected",
        "rejectionReason": reason,
        "timestamps.reviewedAt": FieldValue.serverTimestamp(),
        "reviewedBy": uid,
      });
    });

    await _addLog(jobId, "rejected", reason);
  }

  static Future<void> deleteJob(String jobId) async {
    await _update(jobId, {
      "softDeleted": true,
    });
  }

  static Future<Map<String, dynamic>?> getJobDetails(String jobId) async {
    final doc = await _firestore.collection("jobs").doc(jobId).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  static Stream<QuerySnapshot> getJobLogs(String jobId) {
    return _firestore
        .collection("jobs")
        .doc(jobId)
        .collection("logs")
        .orderBy("performedAt", descending: true)
        .snapshots();
  }
}
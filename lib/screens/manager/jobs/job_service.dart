import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JobService {
  static Future<void> update(String id, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance.collection("jobs").doc(id).update(data);
  }

  static Future<void> approveJob(String id) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await update(id, {
      "status": "approved",
      "approvedByUid": uid,
      "approvedAt": FieldValue.serverTimestamp(),
    });
  }

  static Future<void> rejectJob(String id) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await update(id, {
      "status": "declined",
      "declinedByUid": uid,
      "declinedAt": FieldValue.serverTimestamp(),
    });
  }
}

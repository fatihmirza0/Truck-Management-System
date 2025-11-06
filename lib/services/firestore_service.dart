import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// 🔹 Yeni iş oluştur
  Future<void> createJob({
    required String assignedBy,
    required String assignedTo,
    required String loadPort,
    required String unloadPort,
    required String cargoInfo,
  }) async {
    await _db.collection('jobs').add({
      'assignedBy': assignedBy,
      'assignedTo': assignedTo, // driverId atanıyor
      'loadPort': loadPort,
      'unloadPort': unloadPort,
      'cargoInfo': cargoInfo,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 🔹 Müdür onay bekleyen işleri görür
  Stream<QuerySnapshot> getPendingJobs() {
    return _db
        .collection('jobs')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// 🔹 Müdür işi onaylar
  Future<void> approveJob(String jobId, String approvedBy) async {
    await _db.collection('jobs').doc(jobId).update({
      'status': 'approved',
      'approvedBy': approvedBy,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 🔹 Tüm onaylanmış işleri getir (driver tarafında filtrelenecek)
  Stream<QuerySnapshot> getAllApprovedJobs() {
    return _db
        .collection('jobs')
        .where('status', isEqualTo: 'approved')
        .snapshots();
  }
}

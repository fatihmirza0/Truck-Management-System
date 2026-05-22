import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lojistik/models/mission_model.dart';

class MissionService {
  static final _db = FirebaseFirestore.instance;

  /// Real-time stream of pending + in_progress missions for the given driver.
  /// Firestore offline cache is used automatically (no extra config needed).
  static Stream<List<MissionModel>> watchDriverMissions({
    required String driverId,
    required String companyId,
  }) {
    return _db
        .collection('active_missions')
        .where('companyId', isEqualTo: companyId)
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: ['pending', 'in_progress'])
        .snapshots()
        .map(
          (snap) => snap.docs.map(MissionModel.fromFirestore).toList(),
        );
  }

  static Future<void> acceptMission(String missionId) async {
    await _db.collection('active_missions').doc(missionId).update({
      'status': 'in_progress',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> rejectMission(String missionId) async {
    await _db.collection('active_missions').doc(missionId).update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> completeMission(String missionId) async {
    await _db.collection('active_missions').doc(missionId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }
}

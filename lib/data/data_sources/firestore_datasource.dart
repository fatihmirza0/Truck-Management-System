import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lojistik/data/models/user_model.dart';
import 'package:lojistik/data/models/job_model.dart';

class FirestoreDataSource {
  final FirebaseFirestore _firestore;
  FirestoreDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<UserModel?> fetchUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.id, doc.data() ?? {});
  }

  Stream<List<JobModel>> listenJobs() {
    return _firestore.collection('jobs').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => JobModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }
}

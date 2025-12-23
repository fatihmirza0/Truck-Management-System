import 'package:firebase_storage/firebase_storage.dart';

class StorageDataSource {
  final FirebaseStorage _storage;
  StorageDataSource({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  Future<String> uploadFile(String path, List<int> bytes) async {
    final ref = _storage.ref(path);
    final task = await ref.putData(bytes);
    return task.ref.getDownloadURL();
  }
}

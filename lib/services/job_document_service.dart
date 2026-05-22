import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/job_document_model.dart';
import 'auth_service.dart';

/// Storage ve Firestore işlemlerini yöneten servis.
///
/// Storage path formatı (değiştirilemez — Vue admin bu pathi okur):
///   companies/{company_id}/jobs/{job_id}/{document_type}_{timestamp}.[ext]
///
/// Firestore koleksiyonu: `jobs_document` (root seviyesinde)
class JobDocumentService {
  static final _firestore = FirebaseFirestore.instance;
  static final _storage   = FirebaseStorage.instance;
  static final _auth      = FirebaseAuth.instance;

  // ─────────────────────────────────────────────
  // UPLOAD
  // ─────────────────────────────────────────────

  /// Dosyayı Storage'a yükler ve Firestore'a `jobs_document` kaydı atar.
  ///
  /// [driverName] ve [vehiclePlate] dispatcher onay kartında görüntülenir.
  /// [onProgress] 0.0–1.0 arası upload ilerlemi bildirir (UI progress bar için).
  /// Dönen değer: yeni oluşturulan Firestore dokümanının ID'si.
  static Future<String> uploadDocument({
    required File file,
    required String jobId,
    required JobDocumentType docType,
    String driverName   = '',
    String vehiclePlate = '',
    void Function(double progress)? onProgress,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Kullanıcı oturumu bulunamadı.');

    final companyId = await AuthService.getCompanyId();
    if (companyId == null) throw Exception('Firma bilgisi bulunamadı.');

    // ── 1. Storage path ───────────────────────────────────────────────────
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext       = _extension(file.path);
    final fileName  = '${docType.value}_$timestamp.$ext';
    final storagePath = 'companies/$companyId/jobs/$jobId/$fileName';

    debugPrint('📤 Uploading to Storage: $storagePath');

    // ── 2. Storage yükle ──────────────────────────────────────────────────
    final ref  = _storage.ref(storagePath);
    final task = ref.putFile(
      file,
      SettableMetadata(
        contentType: _contentType(ext),
        customMetadata: {
          'jobId':     jobId,
          'companyId': companyId,
          'driverId':  uid,
          'docType':   docType.value,
        },
      ),
    );

    // İlerleme bildirimi
    if (onProgress != null) {
      task.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
        }
      });
    }

    final snapshot = await task;
    final fileUrl  = await snapshot.ref.getDownloadURL();
    debugPrint('✅ Storage upload complete. URL: $fileUrl');

    // ── 3. Firestore kaydı ────────────────────────────────────────────────
    final doc = JobDocument(
      id:           '',
      jobId:        jobId,
      companyId:    companyId,
      driverId:     uid,
      driverName:   driverName,
      vehiclePlate: vehiclePlate,
      type:         docType.value,
      fileUrl:      fileUrl,
      status:       'pending_approval',
    );

    final ref2 = await _firestore
        .collection('jobs_document')
        .add(doc.toFirestoreMap());

    debugPrint('✅ Firestore record created: jobs_document/${ref2.id}');
    return ref2.id;
  }

  // ─────────────────────────────────────────────
  // READ
  // ─────────────────────────────────────────────

  /// Bir işe ait tüm evrakları gerçek zamanlı olarak dinler.
  static Stream<List<JobDocument>> streamDocuments(String jobId) {
    return _firestore
        .collection('jobs_document')
        .where('job_id', isEqualTo: jobId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map(JobDocument.fromFirestore).toList());
  }

  /// Bir işe ait tüm evrakları tek seferlik çeker.
  static Future<List<JobDocument>> fetchDocuments(String jobId) async {
    final snap = await _firestore
        .collection('jobs_document')
        .where('job_id', isEqualTo: jobId)
        .orderBy('uploadedAt', descending: true)
        .get();
    return snap.docs.map(JobDocument.fromFirestore).toList();
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  static String _extension(String path) {
    final parts = path.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : 'jpg';
  }

  static String _contentType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png':  return 'image/png';
      case 'pdf':  return 'application/pdf';
      default:     return 'application/octet-stream';
    }
  }
}

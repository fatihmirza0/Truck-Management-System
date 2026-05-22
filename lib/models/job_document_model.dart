import 'package:cloud_firestore/cloud_firestore.dart';

/// Evrak tipleri — Vue admin paneli bu string değerleri okur; değiştirmeden kullanın.
enum JobDocumentType {
  kantarFisi('kantar_fisi', 'Kantar Fişi', '⚖️'),
  yakitFisi('yakit_fisi', 'Yakıt Fişi', '⛽'),
  teslimatTutanagi('teslimat_tutanagi', 'Teslimat Tutanağı', '📋'),
  yuklemeTutanagi('yukleme_tutanagi', 'Yükleme Tutanağı', '🚛'),
  diger('diger', 'Diğer', '📎');

  final String value;
  final String label;
  final String emoji;
  const JobDocumentType(this.value, this.label, this.emoji);

  static JobDocumentType fromValue(String v) =>
      JobDocumentType.values.firstWhere(
        (e) => e.value == v,
        orElse: () => JobDocumentType.diger,
      );
}

/// Firestore `jobs_document` koleksiyonundaki tek bir dokümanı temsil eder.
/// Alan isimleri Vue admin paneliyle birebir uyumlu olmalıdır.
class JobDocument {
  final String id;           // Firestore auto-ID
  final String jobId;        // jobs / active_missions doküman ID'si
  final String companyId;    // Firma izolasyonu
  final String driverId;     // Yükleyen şoför UID'si
  final String driverName;   // Dispatcher kartında gösterilir
  final String vehiclePlate; // Dispatcher kartında gösterilir
  final String type;         // 'kantar_fisi', 'yakit_fisi', vb.
  final String fileUrl;      // Firebase Storage download URL
  final String status;       // 'pending_approval' | 'approved' | 'rejected'
  final DateTime? uploadedAt;

  const JobDocument({
    required this.id,
    required this.jobId,
    required this.companyId,
    required this.driverId,
    this.driverName   = '',
    this.vehiclePlate = '',
    required this.type,
    required this.fileUrl,
    required this.status,
    this.uploadedAt,
  });

  factory JobDocument.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return JobDocument(
      id:           doc.id,
      jobId:        d['job_id']       ?? '',
      companyId:    d['company_id']   ?? '',
      driverId:     d['driver_id']    ?? '',
      driverName:   d['driverName']   ?? '',
      vehiclePlate: d['vehiclePlate'] ?? '',
      type:         d['type']         ?? '',
      fileUrl:      d['fileUrl']      ?? '',
      status:       d['status']       ?? 'pending_approval',
      uploadedAt:   (d['uploadedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Firestore'a yazılacak Map — key isimleri Vue şemasıyla birebir.
  Map<String, dynamic> toFirestoreMap() => {
    'job_id':       jobId,
    'company_id':   companyId,
    'driver_id':    driverId,
    'driverName':   driverName,
    'vehiclePlate': vehiclePlate,
    'type':         type,
    'fileUrl':      fileUrl,
    'status':       status,
    'uploadedAt':   FieldValue.serverTimestamp(),
  };
}

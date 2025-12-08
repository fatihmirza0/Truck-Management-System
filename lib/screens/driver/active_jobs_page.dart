import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lojistik/screens/driver/upload_document_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lojistik/widgets/empty_state.dart';

class ActiveJobsPage extends StatefulWidget {
  final String uid; // 🔥 artık driverId DEĞİL UID

  const ActiveJobsPage({super.key, required this.uid});

  @override
  State<ActiveJobsPage> createState() => _ActiveJobsPageState();
}

class _ActiveJobsPageState extends State<ActiveJobsPage> {
  bool _isLoading = false;

  /// 🔹 Bu şoföre atanmış aktif işleri çek
  Stream<QuerySnapshot> _getActiveJobs() {
    return FirebaseFirestore.instance
        .collection('jobs')
        .where('status', isEqualTo: 'approved')
        .where('assignedToUid', isEqualTo: widget.uid) // 🔥 UID kullanılıyor
        .snapshots();
  }

  /// 🔹 Google Maps aç
  Future<void> _openMaps(String query) async {
    if (query.isEmpty) return;
    final encoded = Uri.encodeComponent(query);

    final url = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=$encoded",
    );

    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getActiveJobs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final jobs = snapshot.data?.docs ?? [];

        if (jobs.isEmpty) {
          return const EmptyState(message: "Aktif iş bulunamadı.");
        }

        final job = jobs.first;
        final jobData = job.data() as Map<String, dynamic>;
        final jobId = job.id;

        return Container(
          color: const Color(0xFFF5F5F7),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.local_shipping_outlined,
                      color: Colors.blueAccent, size: 30),
                  SizedBox(width: 8),
                  Text("Aktif İş",
                      style:
                      TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                "Şu anda üzerinizdeki aktif iş.",
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                        color: Colors.black.withOpacity(0.05),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow("📦 Yük Bilgisi", jobData['cargoInfo']),
                      const SizedBox(height: 16),

                      _locationBox(
                        title: "Yükleme Noktası",
                        value: jobData['loadPort'],
                        color: Colors.blueAccent,
                        onTap: () => _openMaps(jobData['loadPort']),
                      ),
                      const SizedBox(height: 20),

                      _locationBox(
                        title: "Varış Noktası",
                        value: jobData['unloadPort'],
                        color: Colors.green,
                        onTap: () => _openMaps(jobData['unloadPort']),
                      ),
                      const SizedBox(height: 20),

                      /// 🔹 Dispatch bilgisi — YENİ MİMARİ: assignedBy = dispatchUid
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(jobData['assignedByUid'])
                            .get(),
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return _infoRow("👤 Dispatch", "Yükleniyor...");
                          }

                          final dispatch = snap.data!.data() as Map<String, dynamic>?;

                          if (dispatch == null) {
                            return _infoRow("👤 Dispatch", "Bulunamadı");
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _infoRow("👤 Dispatch", dispatch['name']),
                              _infoRow("📞 Telefon", dispatch['phone'] ?? "-"),
                            ],
                          );
                        },
                      ),

                      const Spacer(),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    UploadDocumentsPage(jobId: jobId),
                              ),
                            );
                          },
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text(
                            "Evrak Yükle ve Tamamla",
                            style: TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Bilgi satırı
  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(value ?? "-", style: const TextStyle(color: Colors.black54)),
          ),
        ],
      ),
    );
  }

  /// Konum kutusu
  Widget _locationBox({
    required String title,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800])),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.place, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
              ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Git"),
              )
            ],
          ),
        ),
      ],
    );
  }
}

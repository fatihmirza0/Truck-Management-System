import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lojistik/screens/driver/upload_document_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lojistik/widgets/empty_state.dart';

class ActiveJobsPage extends StatefulWidget {
  final String driverId;

  const ActiveJobsPage({super.key, required this.driverId});

  @override
  State<ActiveJobsPage> createState() => _ActiveJobsPageState();
}

class _ActiveJobsPageState extends State<ActiveJobsPage> {
  bool _isLoading = false;

  Stream<QuerySnapshot> _getApprovedJobs() {
    return FirebaseFirestore.instance
        .collection('jobs')
        .where('status', isEqualTo: 'approved')
        .where('assignedTo', isEqualTo: widget.driverId)
        .snapshots();
  }

  Future<void> _completeJob(String jobId, BuildContext context) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("İş tamamlandı ✅"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("HATAAAAAAAAAAA: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Hata oluştu: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 🔗 Google Maps yönlendirme
  Future<void> _openMaps(String query) async {
    if (query.isEmpty) return;
    final encodedQuery = Uri.encodeComponent(query);
    final url = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=$encodedQuery",
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // void _showCompleteConfirm(BuildContext context, String jobId) {
  //   showDialog(
  //     context: context,
  //     builder: (ctx) => AlertDialog(
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //       title: const Text("İşi Tamamla"),
  //       content:
  //           const Text("Bu işi tamamlandı olarak işaretlemek istiyor musun?"),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(ctx),
  //           child: const Text("İptal"),
  //         ),
  //         ElevatedButton(
  //           onPressed: () {
  //             Navigator.pop(ctx);
  //             _completeJob(jobId, context);
  //           },
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: Colors.green,
  //             foregroundColor: Colors.white,
  //           ),
  //           child: const Text("Evet, Tamamla"),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getApprovedJobs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final jobs = snapshot.data?.docs ?? [];
        if (jobs.isEmpty) {
          return const EmptyState(message: "Aktif iş bulunamadı.");
        }

        // 🔹 Bu sayfada sadece 1 aktif iş olacak
        final job = jobs.first;
        final jobData = job.data() as Map<String, dynamic>;
        final jobId = job.id;

        return Container(
          color: const Color(0xFFF5F5F7),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Üst başlık
              Row(
                children: const [
                  Icon(Icons.local_shipping_outlined,
                      color: Colors.blueAccent, size: 30),
                  SizedBox(width: 8),
                  Text(
                    "Aktif İş",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "Şu anda üzerinizdeki aktif iş detayları.",
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),

              // Orta alan: tüm sayfayı dolduran panel
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
                      // Yük bilgisi
                      _infoRow("📦 Yük Bilgisi", jobData['cargoInfo']),
                      const SizedBox(height: 16),

                      // Yükleme alanı
                      Text(
                        "Yükleme Noktası",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blueAccent.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.place_outlined,
                                size: 22, color: Colors.blueAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                jobData['loadPort'] ?? '-',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _openMaps(jobData['loadPort'] ?? ''),
                              icon: const Icon(Icons.navigation),
                              label: const Text("Git"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Varış alanı
                      Text(
                        "Varış Noktası",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.flag_outlined,
                                size: 22, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                jobData['unloadPort'] ?? '-',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _openMaps(jobData['unloadPort'] ?? ''),
                              icon: const Icon(Icons.navigation),
                              label: const Text("Git"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .where('dispatchId', isEqualTo: jobData['assignedBy'])
                            .limit(1)
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return _infoRow("👤 Dispatch", "Yükleniyor...");
                          }

                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return _infoRow("👤 Dispatch", "Bulunamadı");
                          }

                          final userData =
                          snapshot.data!.docs.first.data() as Map<String, dynamic>;

                          final dispatchName = userData['name'] ?? "Bilinmiyor";
                          final dispatchPhone = userData['phone'] ?? "-";

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _infoRow("👤 Dispatch", dispatchName),
                              _infoRow("📞 Telefon", dispatchPhone),
                            ],
                          );
                        },
                      ),

                      const Spacer(),

                      // Alt tarafta büyük tamamlandı butonu
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UploadDocumentsPage(jobId: jobId),
                              ),
                            );
                          },
                          icon: _isLoading
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons.upload_file_rounded),
                          label: const Text(
                            "Evrak Yükle ve Tamamla",
                            style: TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
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

  /// Basit bilgi satırı
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
            child: Text(
              value ?? '-',
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lojistik/screens/driver/upload_document_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lojistik/widgets/empty_state.dart';

class ActiveJobsPage extends StatefulWidget {
  final String uid;

  const ActiveJobsPage({super.key, required this.uid});

  @override
  State<ActiveJobsPage> createState() => _ActiveJobsPageState();
}

class _ActiveJobsPageState extends State<ActiveJobsPage> {
  // ===============================
  // UI TOKENS (JobsPage ile aynı dil)
  // ===============================
  static const Color primary = Color(0xFF1E3A5F);
  static const Color bg = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  // ===============================
  // FIRESTORE
  // ===============================
  Stream<QuerySnapshot> _getActiveJobs() {
    return FirebaseFirestore.instance
        .collection('jobs')
        .where('status', isEqualTo: 'approved')
        .where('assignedToUid', isEqualTo: widget.uid)
        .snapshots();
  }

  // ===============================
  // MAPS
  // ===============================
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
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _getActiveJobs(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(primary),
                ),
              );
            }

            final jobs = snapshot.data?.docs ?? [];

            if (jobs.isEmpty) {
              return const EmptyState(message: "Aktif iş bulunamadı.");
            }

            final job = jobs.first;
            final data = job.data() as Map<String, dynamic>;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===================================================
                  // HEADER
                  // ===================================================
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.local_shipping_outlined,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Aktif İş",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              color: primary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Üzerinizde bulunan aktif sevkiyat bilgileri",
                            style: TextStyle(
                              fontSize: 14,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ===================================================
                  // MAIN CARD
                  // ===================================================
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow("Yük Bilgisi", data['cargoInfo']),
                        const SizedBox(height: 20),
                        const Divider(height: 1),

                        const SizedBox(height: 20),
                        _routeRow(
                          title: "Yükleme Noktası",
                          value: data['loadPort'],
                          onMap: () => _openMaps(data['loadPort']),
                        ),

                        const SizedBox(height: 20),
                        _routeRow(
                          title: "Varış Noktası",
                          value: data['unloadPort'],
                          onMap: () => _openMaps(data['unloadPort']),
                        ),

                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 20),

                        // ===================================================
                        // DISPATCH INFO
                        // ===================================================
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(data['assignedByUid'])
                              .get(),
                          builder: (context, snap) {
                            if (!snap.hasData) {
                              return _infoRow("Dispatch", "Yükleniyor...");
                            }

                            final dispatch =
                            snap.data!.data() as Map<String, dynamic>?;

                            if (dispatch == null) {
                              return _infoRow("Dispatch", "Bulunamadı");
                            }

                            return Column(
                              children: [
                                _infoRow("Dispatch", dispatch['name']),
                                const SizedBox(height: 8),
                                _infoRow(
                                    "Telefon", dispatch['phone'] ?? "-"),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 32),

                        // ===================================================
                        // ACTION BUTTON
                        // ===================================================
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      UploadDocumentsPage(jobId: job.id),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding:
                              const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Evrak Yükle ve İşi Tamamla",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ===================================================
  // INFO ROW
  // ===================================================
  Widget _infoRow(String label, String? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textMuted,
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            value ?? "-",
            style: const TextStyle(
              fontSize: 14,
              color: textDark,
            ),
          ),
        ),
      ],
    );
  }

  // ===================================================
  // ROUTE ROW (KURUMSAL, RENKSİZ)
  // ===================================================
  Widget _routeRow({
    required String title,
    required String value,
    required VoidCallback onMap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textMuted,
            letterSpacing: .6,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(
              Icons.place_outlined,
              size: 18,
              color: Color(0xFF475569),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textDark,
                ),
              ),
            ),
            IconButton(
              onPressed: onMap,
              icon: const Icon(Icons.map_outlined, size: 20),
              color: primary,
              tooltip: "Haritada aç",
            ),
          ],
        ),
      ],
    );
  }
}

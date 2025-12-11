import 'package:flutter/material.dart';
import 'job_documents.dart';

// ============================================
// MODERN MINIMAL DETAIL PANEL
// Görsel tasarıma göre düzenlenmiş
// ============================================


class JobDetailPanel extends StatelessWidget {

  final Map job;
  final String jobId;
  final String Function(String?) uname;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const JobDetailPanel({
    super.key,
    required this.job,
    required this.jobId,
    required this.uname,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Drawer(
      width: 480,
      backgroundColor: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Header - Koyu mavi (görseldeki gibi)

          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 22,
              vertical: isMobile ? 12 : 18,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1E3A5F),
            ),
            child: Center(
              child: Row(
                children: [
                  Icon(
                    Icons.description,
                    size: isMobile ? 16 : 20,
                    color: Colors.white.withOpacity(.9),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "İş Detayları",
                    style: TextStyle(
                      fontSize: isMobile ? 15 : 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      size: isMobile ? 18 : 22,
                      color: Colors.white.withOpacity(.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Cards - Görseldeki minimal tasarım
                  _buildMinimalCard("Yük Bilgisi", job["cargoInfo"],
                      Icons.inventory_2_outlined),
                  const SizedBox(height: 12),
                  _buildMinimalCard("Şoför", uname(job["assignedToUid"]),
                      Icons.person_outline),
                  const SizedBox(height: 12),
                  _buildMinimalCard("Yükleme Noktası", job["loadPort"],
                      Icons.location_on_outlined),
                  const SizedBox(height: 12),
                  _buildMinimalCard(
                      "Varış Noktası", job["unloadPort"], Icons.flag_outlined),
                  const SizedBox(height: 12),
                  _buildMinimalCard("Dispatch", uname(job["assignedByUid"]),
                      Icons.support_agent_outlined),
                  const SizedBox(height: 24),

                  // Documents Section
                  if (job["status"] == "completed") ...[
                    JobDocuments(documents: job["documents"] ?? []),
                    const SizedBox(height: 24),
                  ],

                  // Action Buttons - Görsel tasarıma uygun
                  if (job["status"] == "pending")
                    Column(
                      children: [
                        // Reddet butonu
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: onReject,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE53E3E),
                              side: const BorderSide(
                                  color: Color(0xFFE53E3E), width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Reddet",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Onayla butonu
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: onApprove,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF38A169),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Onayla",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Görseldeki minimal kart tasarımı
  Widget _buildMinimalCard(String title, dynamic value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Soluk gri badge - görseldeki gibi
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEDF2F7), // Çok açık gri
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 24,
              color: const Color(0xFF4A5568), // Orta gri
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF718096), // Açık gri
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value?.toString() ?? "-",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748), // Koyu gri
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Eski metodlar (backward compatibility için)
  Widget _header(BuildContext c) =>
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text("İş Detayı",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(c)),
          ],
        ),
      );

  Widget _info(String k, dynamic v) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: const TextStyle(color: Colors.grey)),
            Text(v?.toString() ?? "-",
                style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

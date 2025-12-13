import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CompletedJobDetailsPage extends StatelessWidget {
  final Map<String, dynamic> job;

  const CompletedJobDetailsPage({super.key, required this.job});

  // ======================================================
  // UI TOKENS (CompletedJobsPage ile AYNI)
  // ======================================================
  static const Color primary = Color(0xFF1E3A5F);
  static const Color bg = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final createdAt = (job['createdAt'] as Timestamp?)?.toDate();
    final approvedAt = (job['approvedAt'] as Timestamp?)?.toDate();
    final completedAt = (job['completedAt'] as Timestamp?)?.toDate();
    final distanceKm = job['distanceKm'];
    final documents = job['documents'];

    String durationText = "-";
    if (createdAt != null && completedAt != null) {
      final diff = completedAt.difference(createdAt);
      durationText =
      "${diff.inHours} saat ${diff.inMinutes.remainder(60)} dk";
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: textDark,
        title: const Text(
          "Tamamlanan İş Detayı",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===================================================
            // ROUTE + DISTANCE
            // ===================================================
            _sectionTitle("Güzergah"),
            _card(
              child: Column(
                children: [
                  _infoRow(
                    icon: Icons.location_on_outlined,
                    label: "Yükleme",
                    value: job['loadPort'] ?? "-",
                  ),
                  const Divider(height: 24),
                  _infoRow(
                    icon: Icons.flag_outlined,
                    label: "Varış",
                    value: job['unloadPort'] ?? "-",
                  ),
                  if (distanceKm != null) ...[
                    const Divider(height: 24),
                    _infoRow(
                      icon: Icons.route_outlined,
                      label: "Toplam Mesafe",
                      value: "$distanceKm km",
                    ),
                  ]
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ===================================================
            // DISPATCH
            // ===================================================
            _sectionTitle("Dispatch"),
            _dispatchInfo(job['assignedByUid']),

            const SizedBox(height: 20),

            // ===================================================
            // DATES
            // ===================================================
            _sectionTitle("İşlem Tarihleri"),
            _card(
              child: Column(
                children: [
                  _dateRow("Oluşturulma", createdAt),
                  _dateRow("Onaylanma", approvedAt),
                  _dateRow("Tamamlanma", completedAt),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ===================================================
            // DURATION
            // ===================================================
            _sectionTitle("Toplam Süre"),
            _card(
              child: Text(
                durationText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textDark,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ===================================================
            // DOCUMENTS
            // ===================================================
            _sectionTitle("Yüklenen Evraklar"),
            _buildDocuments(context, documents),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // DISPATCH INFO
  // ======================================================
  Widget _dispatchInfo(String? uid) {
    if (uid == null || uid.isEmpty) {
      return _card(child: const Text("Bilgi bulunamadı"));
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection("users").doc(uid).get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return _card(child: const Text("Yükleniyor..."));
        }

        if (!snap.data!.exists) {
          return _card(child: const Text("Dispatch bulunamadı"));
        }

        final data = snap.data!.data() as Map<String, dynamic>;
        return _card(
          child: Column(
            children: [
              _infoRow(
                icon: Icons.person_outline,
                label: "İsim",
                value: data['name'] ?? "-",
              ),
              const Divider(height: 24),
              _infoRow(
                icon: Icons.phone_outlined,
                label: "Telefon",
                value: data['phone'] ?? "-",
              ),
            ],
          ),
        );
      },
    );
  }

  // ======================================================
  // DOCUMENTS
  // ======================================================
  Widget _buildDocuments(BuildContext context, dynamic documents) {
    if (documents == null || documents is! List || documents.isEmpty) {
      return _card(
        child: Column(
          children: const [
            Icon(Icons.insert_drive_file_outlined,
                size: 42, color: textMuted),
            SizedBox(height: 10),
            Text(
              "Bu iş için evrak yüklenmemiş",
              style: TextStyle(
                fontSize: 13,
                color: textMuted,
              ),
            ),
          ],
        ),
      );
    }

    final List<String> files = documents.cast<String>();

    return _card(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: files.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemBuilder: (context, i) {
          final url = files[i];

          return GestureDetector(
            onTap: () => _openImage(context, url),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                color: bg,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: textMuted,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  // ======================================================
  // REUSABLE UI PARTS
  // ======================================================
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: primary),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: textMuted,
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateRow(String label, DateTime? date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: textMuted,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              date != null
                  ? DateFormat('dd MMM yyyy HH:mm', 'tr_TR').format(date)
                  : "-",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

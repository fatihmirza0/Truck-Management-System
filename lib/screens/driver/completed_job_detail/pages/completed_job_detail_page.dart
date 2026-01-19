import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../models/job_model.dart';
import '../widgets/detail_card.dart';
import '../widgets/detail_section_title.dart';
import '../widgets/detail_info_row.dart';
import '../widgets/detail_date_row.dart';
import '../widgets/documents_grid.dart';

class CompletedJobDetailsPage extends StatelessWidget {
  final Job job;

  const CompletedJobDetailsPage({super.key, required this.job});

  static const Color bg = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF0F172A);

  DateTime? _createdAt() => job.timestamps.createdAt;
  DateTime? _approvedAt() => job.timestamps.reviewedAt;
  DateTime? _completedAt() => job.timestamps.completedAt;

  @override
  Widget build(BuildContext context) {
    final createdAt = _createdAt();
    final approvedAt = _approvedAt();
    final completedAt = _completedAt();

    final distanceKm = job.distanceKm;

    String durationText = "-";
    if (createdAt != null && completedAt != null) {
      final diff = completedAt.difference(createdAt);
      durationText = "${diff.inHours} saat ${diff.inMinutes.remainder(60)} dk";
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
            const DetailSectionTitle(text: "Güzergah"),
            DetailCard(
              child: Column(
                children: [
                  DetailInfoRow(
                    icon: Icons.location_on_outlined,
                    label: "Yükleme",
                    value: job.loadPort,
                  ),
                  const Divider(height: 24),
                  DetailInfoRow(
                    icon: Icons.flag_outlined,
                    label: "Varış",
                    value: job.unloadPort,
                  ),
                  if (distanceKm > 0) ...[
                    const Divider(height: 24),
                    DetailInfoRow(
                      icon: Icons.route_outlined,
                      label: "Toplam Mesafe",
                      value: "${distanceKm.toString()} km",
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 20),
            const DetailSectionTitle(text: "Dispatch"),
            _dispatchInfo(job.createdBy),
            const SizedBox(height: 20),
            const DetailSectionTitle(text: "İşlem Tarihleri"),
            DetailCard(
              child: Column(
                children: [
                  DetailDateRow(label: "Oluşturulma", date: createdAt),
                  DetailDateRow(label: "İnceleme/Onay", date: approvedAt),
                  DetailDateRow(label: "Tamamlanma", date: completedAt),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const DetailSectionTitle(text: "Toplam Süre"),
            DetailCard(
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
            const DetailSectionTitle(text: "Yüklenen Evraklar"),
            DocumentsGrid(
              documents: job.documents ?? [],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dispatchInfo(String uid) {
    if (uid.isEmpty) {
      return DetailCard(child: const Text("Bilgi bulunamadı"));
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection("users").doc(uid).get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return DetailCard(child: const Text("Yükleniyor..."));
        }

        if (!snap.data!.exists) {
          return DetailCard(child: const Text("Dispatch bulunamadı"));
        }

        final data = (snap.data!.data() as Map<String, dynamic>?) ?? {};
        return DetailCard(
          child: Column(
            children: [
              DetailInfoRow(
                icon: Icons.person_outline,
                label: "İsim",
                value: (data['name'] ?? "-").toString(),
              ),
              const Divider(height: 24),
              DetailInfoRow(
                icon: Icons.phone_outlined,
                label: "Telefon",
                value: (data['phone'] ?? "-").toString(),
              ),
            ],
          ),
        );
      },
    );
  }
}

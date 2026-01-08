// 📁 lib/screens/driver/active_jobs/widgets/active_job_card.dart
import 'package:flutter/material.dart';
import 'info_row.dart';
import 'route_row.dart';
import '../../upload_document/pages/upload_document_page.dart';

class ActiveJobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final String jobId;
  final String driverId;
  final String? vehiclePlate;
  final String? dispatchName;
  final String? dispatchPhone;

  const ActiveJobCard({
    super.key,
    required this.job,
    required this.jobId,
    required this.driverId,
    this.vehiclePlate,
    this.dispatchName,
    this.dispatchPhone,
  });

  static const Color border = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final String referenceNo = (job['referenceNo'] ?? '-').toString();

    final route = (job['route'] as Map?)?.cast<String, dynamic>() ?? {};
    final String loadPort = (route['loadPort'] ?? '-').toString();
    final String unloadPort = (route['unloadPort'] ?? '-').toString();

    final cargo = (job['cargo'] as Map?)?.cast<String, dynamic>() ?? {};
    final String cargoType = (cargo['type'] ?? '-').toString();
    final String cargoDesc = (cargo['description'] ?? '-').toString();
    final dynamic w = cargo['weightKg'];
    final String weightKg = (w == null) ? '-' : w.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoRow(label: "Referans No", value: referenceNo),
          const SizedBox(height: 18),
          InfoRow(
            label: "Yük",
            value: "$cargoType • ${weightKg == '-' ? '-' : '$weightKg kg'}",
          ),
          const SizedBox(height: 8),
          InfoRow(label: "Açıklama", value: cargoDesc),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),
          RouteRow(
            title: "Yükleme Noktası",
            value: loadPort,
          ),
          const SizedBox(height: 20),
          RouteRow(
            title: "Varış Noktası",
            value: unloadPort,
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),
          InfoRow(label: "Plaka", value: vehiclePlate ?? "-"),
          const SizedBox(height: 18),
          if (dispatchName != null) ...[
            InfoRow(label: "Dispatch", value: dispatchName ?? "-"),
            if (dispatchPhone != null) ...[
              const SizedBox(height: 8),
              InfoRow(label: "Telefon", value: dispatchPhone ?? "-"),
            ],
          ] else
            InfoRow(label: "Dispatch", value: "-"),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UploadDocumentsPage(
                      jobId: jobId,
                      driverId: driverId,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 18),
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
    );
  }
}


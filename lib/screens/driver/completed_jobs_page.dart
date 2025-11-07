import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:lojistik/widgets/empty_state.dart';

class CompletedJobsPage extends StatelessWidget {
  final String driverId;

  const CompletedJobsPage({super.key, required this.driverId});

  Stream<QuerySnapshot> _getCompletedJobs() {
    return FirebaseFirestore.instance
        .collection('jobs')
        .where('status', isEqualTo: 'completed')
        .where('assignedTo', isEqualTo: driverId)
        .orderBy('completedAt', descending: true)
        .snapshots();
  }

  void _showJobDetails(BuildContext context, Map<String, dynamic> job) {
    final start = (job['createdAt'] as Timestamp?)?.toDate();
    final end = (job['completedAt'] as Timestamp?)?.toDate();
    String durationText = "-";

    if (start != null && end != null) {
      final diff = end.difference(start);
      final hours = diff.inHours;
      final minutes = diff.inMinutes.remainder(60);
      durationText = "$hours saat ${minutes} dk";
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          children: [
            Center(
              child: Container(
                width: 50,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Row(
              children: const [
                Icon(Icons.info_outline, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text(
                  "Tamamlanan İş Detayları",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _infoRow("📦 Yük Bilgisi", job['cargoInfo']),
            _infoRow("🗺️ Yükleme Limanı", job['loadPort']),
            _infoRow("📍 Varış Limanı", job['unloadPort']),
            _infoRow("👤 Dispatch", job['assignedBy']),
            _infoRow(
              "⏰ Başlangıç",
              start != null ? DateFormat('dd MMM yyyy - HH:mm').format(start) : "-",
            ),
            _infoRow(
              "✅ Tamamlanma",
              end != null ? DateFormat('dd MMM yyyy - HH:mm').format(end) : "-",
            ),
            _infoRow("🕒 Süre", durationText),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  static Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getCompletedJobs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final jobs = snapshot.data?.docs ?? [];

        if (jobs.isEmpty) {
          return const EmptyState(message: "Tamamlanan iş bulunamadı.");
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: jobs.length,
          itemBuilder: (context, i) {
            final job = jobs[i].data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.done_all, color: Colors.green, size: 32),
                title: Text(job['cargoInfo'] ?? 'Bilinmeyen Yük'),
                subtitle: Text("${job['loadPort']} → ${job['unloadPort']}"),
                trailing: const Icon(Icons.info_outline, color: Colors.grey),
                onTap: () => _showJobDetails(context, job),
              ),
            );
          },
        );
      },
    );
  }
}

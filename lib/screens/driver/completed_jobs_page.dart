import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:lojistik/widgets/empty_state.dart';

import 'completed_job_detail_page.dart';

class CompletedJobsPage extends StatefulWidget {
  final String uid; // 🔥 driverUid

  const CompletedJobsPage({super.key, required this.uid});

  @override
  State<CompletedJobsPage> createState() => _CompletedJobsPageState();
}

class _CompletedJobsPageState extends State<CompletedJobsPage> {
  String _selectedFilter = "all";

  // ---------------------------------------------------------------------------
  // 🔥 Tamamlanan işleri çek — UID tabanlı yeni mimari
  // ---------------------------------------------------------------------------
  Stream<QuerySnapshot> _getCompletedJobs() {
    return FirebaseFirestore.instance
        .collection('jobs')
        .where('status', isEqualTo: 'completed')
        .where('assignedToUid', isEqualTo: widget.uid)
        .orderBy('completedAt', descending: true)
        .snapshots();
  }

  // ---------------------------------------------------------------------------
  // 🔥 Filtre başlangıç tarihini hesapla
  // ---------------------------------------------------------------------------
  DateTime? _getStartFilterDate() {
    final now = DateTime.now();

    switch (_selectedFilter) {
      case "today":
        return DateTime(now.year, now.month, now.day);
      case "week":
        return now.subtract(const Duration(days: 7));
      case "month":
        return DateTime(now.year, now.month - 1, now.day);
      case "3months":
        return DateTime(now.year, now.month - 3, now.day);
      default:
        return null; // all
    }
  }

  // ---------------------------------------------------------------------------
  // 🔥 Filtre uygula
  // ---------------------------------------------------------------------------
  bool _filterJob(Map<String, dynamic> job) {
    final filterStart = _getStartFilterDate();
    if (filterStart == null) return true;

    final completedAt = (job['completedAt'] as Timestamp?)?.toDate();
    if (completedAt == null) return true;

    return completedAt.isAfter(filterStart);
  }

  // ---------------------------------------------------------------------------
  // 🔥 UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getCompletedJobs(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        // Map'lere dönüştür ve filtre uygula
        List<Map<String, dynamic>> jobs =
        docs.map((e) => e.data() as Map<String, dynamic>).where(_filterJob).toList();

        if (jobs.isEmpty) {
          return const EmptyState(message: "Tamamlanan iş bulunamadı.");
        }

        // --------------------------------------------------------------------
        // 📊 ÖZET HESAPLAMA
        // --------------------------------------------------------------------
        final total = jobs.length;

        final lastCompletedAt =
        (jobs.first['completedAt'] as Timestamp?)?.toDate();

        Duration totalDuration = Duration.zero;
        for (var j in jobs) {
          final created = (j['createdAt'] as Timestamp?)?.toDate();
          final completed = (j['completedAt'] as Timestamp?)?.toDate();
          if (created != null && completed != null) {
            totalDuration += completed.difference(created);
          }
        }

        final avgMinutes = totalDuration.inMinutes == 0
            ? 0
            : totalDuration.inMinutes ~/ total;

        final avgHour = avgMinutes ~/ 60;
        final avgMin = avgMinutes % 60;

        // --------------------------------------------------------------------
        // 🔥 SAYFA YAPISI
        // --------------------------------------------------------------------
        return Column(
          children: [
            // ---------------------- ÖZET CARD -----------------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Tamamlanan İşler Özeti",
                      style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

                  const SizedBox(height: 8),
                  Text("Toplam iş: $total"),
                  Text("Son tamamlanan: ${lastCompletedAt != null ? DateFormat('dd MMM yyyy HH:mm').format(lastCompletedAt) : "-"}"),
                  Text("Ortalama süre: $avgHour saat $avgMin dk"),
                ],
              ),
            ),

            // ---------------------- FİLTRE BAR -----------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  DropdownButton<String>(
                    value: _selectedFilter,
                    items: const [
                      DropdownMenuItem(value: "all", child: Text("Tümü")),
                      DropdownMenuItem(value: "today", child: Text("Bugün")),
                      DropdownMenuItem(value: "week", child: Text("Bu Hafta")),
                      DropdownMenuItem(value: "month", child: Text("Bu Ay")),
                      DropdownMenuItem(value: "3months", child: Text("3 Ay")),
                    ],
                    onChanged: (v) => setState(() => _selectedFilter = v!),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ---------------------- LİSTE -----------------------
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: jobs.length,
                itemBuilder: (context, i) {
                  final job = jobs[i];

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.check_circle,
                          color: Colors.green, size: 32),

                      title: Text(
                        job['cargoInfo'] ?? 'Bilinmeyen Yük',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),

                      subtitle: Text(
                        "${job['loadPort']} → ${job['unloadPort']}",
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 13),
                      ),

                      trailing: const Icon(Icons.arrow_forward_ios_rounded,
                          size: 18, color: Colors.grey),

                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CompletedJobDetailsPage(job: job),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

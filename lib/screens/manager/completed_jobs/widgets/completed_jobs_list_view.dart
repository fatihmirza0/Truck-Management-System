import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'completed_job_card.dart';

class CompletedJobsListView extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final List<QueryDocumentSnapshot> Function(List<QueryDocumentSnapshot>) applyFilters;
  final String Function(String?) userName;
  final String Function(DateTime) formatDateShort;
  final void Function(Map<String, dynamic> job, String id) onJobTap;

  const CompletedJobsListView({
    super.key,
    required this.stream,
    required this.applyFilters,
    required this.userName,
    required this.formatDateShort,
    required this.onJobTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          // Permission denied or other errors -> Show empty state (or error state)
          return _emptyState();
        }

        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Color(0xFF1E3A5F)),
            ),
          );
        }

        final filtered = applyFilters(snap.data!.docs);

        if (filtered.isEmpty) return _emptyState();

        return GridView.builder(
          padding: const EdgeInsets.only(bottom: 32, top: 8),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 480,
            mainAxisExtent: 265,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final d = filtered[i];
            final j = d.data() as Map<String, dynamic>;
            
            final completedAt = (j["timestamps"]?["completedAt"] as Timestamp?)?.toDate();

            return CompletedJobCard(
              job: j,
              driverName: userName(j["driverId"]),
              dateStr: completedAt == null ? "-" : formatDateShort(completedAt),
              index: i,
              onTap: () => onJobTap(j, d.id),
            );
          },
        );
      },
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Kayıt Bulunamadı",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Seçtiğiniz filtrelerle eşleşen tamamlanan iş yok",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

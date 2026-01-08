// 📁 lib/screens/driver/completed_jobs/widgets/completed_jobs_empty_state.dart
import 'package:flutter/material.dart';

class CompletedJobsEmptyState extends StatelessWidget {
  final bool isFiltered;

  const CompletedJobsEmptyState({
    super.key,
    required this.isFiltered,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFiltered ? Icons.search_off_outlined : Icons.inbox_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            isFiltered ? "Sonuç bulunamadı" : "Tamamlanan iş yok",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}



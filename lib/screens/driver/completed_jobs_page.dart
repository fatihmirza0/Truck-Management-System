import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lojistik/widgets/empty_state.dart';

class CompletedJobsPage extends StatelessWidget {
  final String driverId;

  const CompletedJobsPage({super.key, required this.driverId});

  Stream<QuerySnapshot> _getCompletedJobs() {
    return FirebaseFirestore.instance
        .collection('jobs')
        .where('status', isEqualTo: 'completed')
        .where('assignedTo', isEqualTo: driverId)
        .snapshots();
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
                leading:
                    const Icon(Icons.done_all, color: Colors.green, size: 32),
                title: Text(job['cargoInfo'] ?? 'Bilinmeyen Yük'),
                subtitle: Text("${job['loadPort']} → ${job['unloadPort']}"),
                trailing: const Text(
                  "TAMAMLANDI",
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lojistik/widgets/empty_state.dart';
import '../../../widgets/empty_state.dart';

class ActiveJobsPage extends StatelessWidget {
  final String driverId;
  const ActiveJobsPage({super.key, required this.driverId});

  Stream<QuerySnapshot> _getApprovedJobs() {
    return FirebaseFirestore.instance
        .collection('jobs')
        .where('status', isEqualTo: 'approved')
        .where('assignedTo', isEqualTo: driverId)
        .snapshots();
  }

  Future<void> _completeJob(String jobId, BuildContext context) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("İş tamamlandı ✅"),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showCompleteConfirm(BuildContext context, String jobId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("İşi Tamamla"),
        content:
        const Text("Bu işi tamamlandı olarak işaretlemek istiyor musun?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _completeJob(jobId, context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text("Evet, Tamamla"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getApprovedJobs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final jobs = snapshot.data?.docs ?? [];

        if (jobs.isEmpty) {
          return const EmptyState(message: "Aktif iş bulunamadı.");
        }

        final job = jobs.first; // Tek aktif iş
        final jobData = job.data() as Map<String, dynamic>;
        final jobId = job.id;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 3,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.local_shipping_outlined,
                          color: Colors.blueAccent, size: 32),
                      SizedBox(width: 12),
                      Text(
                        "Aktif İş Bilgileri",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 25),
                  _infoRow("📦 Yük Bilgisi", jobData['cargoInfo']),
                  _infoRow("🗺️ Yükleme Limanı", jobData['loadPort']),
                  _infoRow("📍 Varış Limanı", jobData['unloadPort']),
                  _infoRow("👤 Dispatch", jobData['assignedBy']),
                  const SizedBox(height: 25),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () => _showCompleteConfirm(context, jobId),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text("Tamamlandı"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
          Expanded(
            flex: 4,
            child:
            Text(value ?? '-', style: const TextStyle(color: Colors.black54)),
          ),
        ],
      ),
    );
  }
}

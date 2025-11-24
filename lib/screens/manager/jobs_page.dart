import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JobsPage extends StatefulWidget {
  final String managerId;
  const JobsPage({super.key, required this.managerId});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  Stream<QuerySnapshot> _getJobsByStatus(String status) {
    return FirebaseFirestore.instance
        .collection('jobs')
        .where('status', isEqualTo: status)
        .snapshots();
  } 

  Future<void> _approveJob(String jobId) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'approved',
      'approvedBy': widget.managerId,
    });
  }

  Future<void> _rejectJob(String jobId) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'declined',
    });
  }

  void _openDetails(Map<String, dynamic> job, bool actions, String jobId) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 600;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Container(
            width: 520,
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("İş Detayları", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _detailRow("📦 Yük", job['cargoInfo']),
                _detailRow("🚚 Şoför", job['assignedTo']),
                _detailRow("📍 Yükleme", job['loadPort']),
                _detailRow("🎯 Varış", job['unloadPort']),
                _detailRow("👤 Dispatch", job['assignedBy']),
                const SizedBox(height: 20),
                if (actions)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _approveJob(jobId);
                        },
                        child: const Text("Onayla", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _rejectJob(jobId);
                        },
                        child: const Text("Reddet", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  )
              ],
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (_) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text("İş Detayları", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _detailRow("📦 Yük", job['cargoInfo']),
                _detailRow("🚚 Şoför", job['assignedTo']),
                _detailRow("📍 Yükleme", job['loadPort']),
                _detailRow("🎯 Varış", job['unloadPort']),
                _detailRow("👤 Dispatch", job['assignedBy']),
                const SizedBox(height: 20),
                if (actions)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _approveJob(jobId);
                        },
                        child: const Text("Onayla", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _rejectJob(jobId);
                        },
                        child: const Text("Reddet", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value ?? "-")),
        ],
      ),
    );
  }

  Widget _buildList(Stream<QuerySnapshot> stream, bool actions) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("Bu durumda iş yok."));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final job = docs[i].data() as Map<String, dynamic>;
            final jobId = docs[i].id;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.local_shipping, size: 28),
                title: Text(
                  job['cargoInfo'] ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                subtitle: Text("Şoför: ${job['assignedTo'] ?? '-'}"),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                onTap: () => _openDetails(job, actions, jobId),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Material(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: "Bekleyen"),
                Tab(text: "Onaylanan"),
                Tab(text: "Tamamlanan"),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildList(_getJobsByStatus('pending'), true),
              _buildList(_getJobsByStatus('approved'), false),
              _buildList(_getJobsByStatus('completed'), false),
            ],
          ),
        ),
      ],
    );
  }
}
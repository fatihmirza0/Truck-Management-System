import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JobsPage extends StatefulWidget {
  const JobsPage({super.key});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  // 🔹 İş Onaylama
  Future<void> _approveJob(String jobId, BuildContext context) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'approved',
      'approvedBy': 'manager123',
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("İş onaylandı ✅"),
        backgroundColor: Colors.green,
      ),
    );
  }

  // 🔹 İş Reddetme
  Future<void> _rejectJob(String jobId, BuildContext context) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'declined',
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("İş reddedildi ❌"),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // 🔹 Status'a göre iş listesini getir
  Stream<QuerySnapshot> _getJobsByStatus(String status) {
    return FirebaseFirestore.instance
        .collection('jobs')
        .where('status', isEqualTo: status)
        .snapshots();
  }

  // 🔹 İş Listesi
  Widget _buildJobList(Stream<QuerySnapshot> stream, bool showActions) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final jobs = snapshot.data?.docs ?? [];

        if (jobs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 75, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  "Bu kategoriye ait iş bulunmuyor.",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: jobs.length,
          itemBuilder: (context, i) {
            final job = jobs[i].data() as Map<String, dynamic>;
            final jobId = jobs[i].id;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.local_shipping_outlined,
                    color: Colors.blueAccent),
                title: Text(
                  "Yük: ${job['cargoInfo'] ?? 'Bilinmiyor'}",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Şoför: ${job['assignedTo'] ?? '-'}"),
                    Text("Dispatch: ${job['assignedBy'] ?? '-'}"),
                  ],
                ),
                trailing: null, // ❌ Kart üzerinde artık onay/red yok
                onTap: () =>
                    _showJobDetails(context, job, showActions, jobId), // 👇 Detay ekranına geçiş
              ),
            );
          },
        );
      },
    );
  }

  // 🔹 İş Detayları (Dialog)
  void _showJobDetails(BuildContext context, Map<String, dynamic> job,
      bool showActions, String jobId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("İş Detayları"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("📦 Yük: ${job['cargoInfo'] ?? '-'}"),
            Text("🚚 Şoför: ${job['assignedTo'] ?? '-'}"),
            Text("🗺️ Yükleme Limanı: ${job['loadPort'] ?? '-'}"),
            Text("📍 Varış Limanı: ${job['unloadPort'] ?? '-'}"),
            Text("👤 Dispatch: ${job['assignedBy'] ?? '-'}"),
          ],
        ),
        actions: showActions
            ? [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _approveJob(jobId, context);
            },
            child: const Text(
              "Onayla",
              style: TextStyle(color: Colors.green),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectJob(jobId, context);
            },
            child: const Text(
              "Reddet",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ]
            : [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Kapat"),
          ),
        ],
      ),
    );
  }

  // 🔹 Ekran Yapısı
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: AppBar(
          elevation: 0,
          automaticallyImplyLeading: false,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.blueAccent,
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: "Bekleyen"),
              Tab(text: "Onaylanan"),
              Tab(text: "Tamamlanan"),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildJobList(_getJobsByStatus('pending'), true), // Bekleyen → Onay/Red aktif
          _buildJobList(_getJobsByStatus('approved'), false),
          _buildJobList(_getJobsByStatus('completed'), false),
        ],
      ),
    );
  }
}

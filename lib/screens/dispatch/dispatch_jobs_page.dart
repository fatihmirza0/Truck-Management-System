import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'dispatch_job_detail_page.dart';

class DispatchJobsPage extends StatefulWidget {
  final String uid; // FirebaseAuth.currentUser!.uid

  const DispatchJobsPage({super.key, required this.uid});

  @override
  State<DispatchJobsPage> createState() => _DispatchJobsPageState();
}

class _DispatchJobsPageState extends State<DispatchJobsPage> {
  static const Color _bgColor = Color(0xfff5f6fa);
  static const Color _accent = Color(0xff2563eb);

  String? _dispatchId;
  bool _loading = true;

  /// driverId -> driverName
  final Map<String, String> _driverNames = {};

  @override
  void initState() {
    super.initState();
    _initData();
  }

  // ---------------------------------------------------------------------------
  // INIT : dispatchId + driver isimleri
  // ---------------------------------------------------------------------------
  Future<void> _initData() async {
    try {
      // 1) Kullanıcının dispatchId'sini al
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get();

      _dispatchId = userDoc.data()?['dispatchId'];

      // 2) Tüm driver'ları çek ve driverId -> name map'ini doldur
      final driversSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('roleId', isEqualTo: 'driver')
          .get();

      for (var d in driversSnap.docs) {
        final data = d.data();
        final driverId = data['driverId'];
        final name = data['name'];
        if (driverId != null && name != null) {
          _driverNames[driverId.toString()] = name.toString();
        }
      }
    } catch (e) {
      debugPrint('DispatchJobsPage init error: $e');
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // STREAMS
  // ---------------------------------------------------------------------------
  Stream<QuerySnapshot> _jobsByStatus(String status) {
    if (_dispatchId == null) {
      return const Stream<QuerySnapshot>.empty();
    }

    return FirebaseFirestore.instance
        .collection('jobs')
        .where('assignedBy', isEqualTo: _dispatchId)
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ---------------------------------------------------------------------------
  // DRIVER NAME LOOKUP
  // ---------------------------------------------------------------------------
  String _driverName(String? driverId) {
    if (driverId == null || driverId.isEmpty) return '-';
    return _driverNames[driverId] ?? driverId;
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_dispatchId == null) {
      return const Scaffold(
        body: Center(child: Text('Dispatch ID bulunamadı.')),
      );
    }

    // *** TEK DefaultTabController TÜM Scaffold'U SARAR ***
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
          toolbarHeight: 0, // ← yükseklik sıfırlandı
          bottom: const TabBar(
            indicatorColor: _accent,
            labelColor: _accent,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Bekleyen'),
              Tab(text: 'Reddedilen'),
              Tab(text: 'Tamamlanan'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _jobList(_jobsByStatus('pending')),
            _jobList(_jobsByStatus('declined')),
            _jobList(_jobsByStatus('completed')),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // JOB LIST
  // ---------------------------------------------------------------------------
  Widget _jobList(Stream<QuerySnapshot> stream) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return Center(child: Text('Hata: ${snap.error}'));
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'Kayıt bulunamadı.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          );
        }

        final docs = snap.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final doc = docs[i];
            final job = doc.data() as Map<String, dynamic>;
            final status = (job['status'] ?? '').toString();
            return _jobCard(job: job, jobId: doc.id, status: status);
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // JOB CARD
  // ---------------------------------------------------------------------------
  Widget _jobCard({
    required Map<String, dynamic> job,
    required String jobId,
    required String status,
  }) {
    final String driverId = (job['assignedTo'] ?? '') as String;
    final String driverName = _driverName(driverId);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DispatchJobDetailPage(
              jobId: jobId,
              data: job,
              canEdit: status == 'declined', // sadece reddedilenleri düzenleyebil
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_shipping, color: _accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job['cargoInfo'] ?? '-',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Şoför: $driverName',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Yükleme: ${job['loadPort'] ?? '-'}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    'Varış: ${job['unloadPort'] ?? '-'}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            _statusBadge(status),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STATUS BADGE
  // ---------------------------------------------------------------------------
  Widget _statusBadge(String status) {
    Color bg, text;

    switch (status) {
      case 'pending':
        bg = Colors.orange.shade100;
        text = Colors.orange.shade800;
        break;
      case 'declined':
        bg = Colors.red.shade100;
        text = Colors.red.shade800;
        break;
      case 'approved':
      case 'completed':
        bg = Colors.green.shade100;
        text = Colors.green.shade800;
        break;
      default:
        bg = Colors.grey.shade200;
        text = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }
}

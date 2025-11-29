import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class JobsPage extends StatefulWidget {
  final String managerId;

  const JobsPage({super.key, required this.managerId});

  static const Color _accent = Color(0xFF2563EB);

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  String _status = "pending"; // pending, approved, completed
  Map<String, dynamic>? _selectedJob;
  String? _selectedJobId;

  bool _loading = false;
  final Map<String, String> _userNames = {}; // driverId / dispatchId → name

  bool get isDesktop => MediaQuery.of(context).size.width > 900;

  @override
  void initState() {
    super.initState();
    _fetchAllUsers();
  }

  /// USERS cache load
  Future<void> _fetchAllUsers() async {
    final snap = await FirebaseFirestore.instance.collection('users').get();
    for (var d in snap.docs) {
      final data = d.data();
      if (data['driverId'] != null) {
        _userNames[data['driverId']] = data['name'] ?? "-";
      }
      if (data['dispatchId'] != null) {
        _userNames[data['dispatchId']] = data['name'] ?? "-";
      }
    }
    setState(() {});
  }

  String userName(String? id) => _userNames[id] ?? "-";

  /// ----------------------------------------------------------
  /// FIRESTORE JOB STREAM
  /// ----------------------------------------------------------
  Stream<QuerySnapshot> _jobs(String status) {
    return FirebaseFirestore.instance
        .collection('jobs')
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// ----------------------------------------------------------
  /// ACTIONS
  /// ----------------------------------------------------------
  Future<void> _updateJob(String id, Map<String, dynamic> data) async {
    setState(() => _loading = true);

    try {
      await FirebaseFirestore.instance.collection('jobs').doc(id).update(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("İş güncellendi")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Hata: $e")));
    }

    setState(() => _loading = false);
  }

  Future<void> approve(id) =>
      _updateJob(id, {"status": "approved", "approvedBy": widget.managerId});

  Future<void> reject(id) =>
      _updateJob(id, {"status": "declined", "rejectedBy": widget.managerId});

  /// ----------------------------------------------------------
  /// OPEN DETAILS
  /// ----------------------------------------------------------
  void _openJobDetail(Map<String, dynamic> job, String id) {
    if (isDesktop) {
      setState(() {
        _selectedJob = job;
        _selectedJobId = id;
      });
      Future.microtask(() => _scaffoldKey.currentState?.openEndDrawer());
    } else {
      _openMobile(job, id);
    }
  }

  void _openMobile(Map<String, dynamic> job, String id) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _DetailSheet(
        job: job,
        jobId: id,
        canAct: _status == "pending",
        approve: approve,
        reject: reject,
        nameOf: userName,
        accentColor: JobsPage._accent,  // ✅ EKLENDİ
      ),
    );
  }

  /// ----------------------------------------------------------
  /// DESKTOP TABLE ROW
  /// ----------------------------------------------------------
  DataRow buildRow(Map<String, dynamic> job, String id) {
    return DataRow(cells: [
      clickable(job['cargoInfo'], () => _openJobDetail(job, id)),
      clickable(userName(job['assignedTo']), () => _openJobDetail(job, id)),
      clickable(job['loadPort'], () => _openJobDetail(job, id)),
      clickable(job['unloadPort'], () => _openJobDetail(job, id)),
      clickable(userName(job['assignedBy']), () => _openJobDetail(job, id)),
      DataCell(Row(children: [
        IconButton(
            icon: const Icon(Icons.remove_red_eye_outlined),
            onPressed: () => _openJobDetail(job, id)),
        if (_status == "pending") ...[
          IconButton(
              icon: const Icon(Icons.check_circle_outline, color: Colors.green),
              onPressed: () => approve(id)),
          IconButton(
              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
              onPressed: () => reject(id)),
        ]
      ])),
    ]);
  }

  DataCell clickable(dynamic text, VoidCallback f) =>
      DataCell(GestureDetector(onTap: f, child: Text(text?.toString() ?? "-")));

  /// ----------------------------------------------------------
  /// MOBILE CARD
  /// ----------------------------------------------------------
  Widget mobileCard(Map<String, dynamic> job, String id) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: () => _openJobDetail(job, id),
        title: Text(job['cargoInfo'] ?? "-",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Şoför: ${userName(job['assignedTo'])}"),
          Text("Yükleme: ${job['loadPort']}"),
          Text("Varış: ${job['unloadPort']}"),
        ]),
        trailing: _status == "pending"
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () => approve(id)),
                IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    onPressed: () => reject(id)),
              ])
            : null,
      ),
    );
  }

  /// ----------------------------------------------------------
  /// BUILD
  /// ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF7F8FA),
      endDrawer: _selectedJob == null
          ? null
          : Drawer(
              width: 420,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _DetailDesktop(
                    job: _selectedJob!,
                    jobId: _selectedJobId!,
                    canAct: _status == "pending",
                    loading: _loading,
                    approve: approve,
                    reject: reject,
                    nameOf: userName,
                    accentColor: JobsPage._accent,   // ✅ EKLENDİ
                  ),
                ),
              ),
            ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? 32 : 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("İşler",
                style: TextStyle(
                    fontSize: isDesktop ? 26 : 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),

            /// Filter chips
            Row(children: [
              _chip("pending", "Bekleyen"),
              _chip("approved", "Onaylanan"),
              _chip("completed", "Tamamlanan"),
            ]),
            const SizedBox(height: 18),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _jobs(_status),
                builder: (_, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(child: Text("Henüz iş yok"));
                  }

                  return isDesktop
                      ? SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                              columns: const [
                                DataColumn(label: Text("Yük")),
                                DataColumn(label: Text("Şoför")),
                                DataColumn(label: Text("Yükleme")),
                                DataColumn(label: Text("Varış")),
                                DataColumn(label: Text("Dispatch")),
                                DataColumn(label: Text("İşlemler")),
                              ],
                              rows: docs
                                  .map((d) => buildRow(
                                      d.data() as Map<String, dynamic>, d.id))
                                  .toList()),
                        )
                      : ListView(
                          children: docs
                              .map((d) => mobileCard(
                                  d.data() as Map<String, dynamic>, d.id))
                              .toList());
                },
              ),
            )
          ]),
        ),
      ),
    );
  }

  Widget _chip(String key, String label) {
    final selected = _status == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: JobsPage._accent.withOpacity(0.15),
        labelStyle: TextStyle(
          color: selected ? JobsPage._accent : Colors.black87,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) => setState(() => _status = key),
      ),
    );
  }
}

/// ===================================================================
/// DESKTOP DETAIL PANEL
/// ===================================================================
class _DetailDesktop extends StatelessWidget {
  final Map<String, dynamic> job;
  final String jobId;
  final bool canAct;
  final bool loading;
  final Function(String) approve;
  final Function(String) reject;
  final String Function(String?) nameOf;
  final Color accentColor;

  const _DetailDesktop({
    required this.job,
    required this.jobId,
    required this.canAct,
    required this.loading,
    required this.approve,
    required this.reject,
    required this.nameOf,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(
            child: Text("İş Detayları",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
        IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close)),
      ]),
      const SizedBox(height: 16),
      _row("Yük", job['cargoInfo']),
      _row("Şoför", nameOf(job['assignedTo'])),
      _row("Yükleme", job['loadPort']),
      _row("Varış", job['unloadPort']),
      _row("Dispatch", nameOf(job['assignedBy'])),
      const SizedBox(height: 18),
      if (canAct)
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(
              onPressed: () => reject(jobId),
              child: const Text("Reddet", style: TextStyle(color: Colors.red))),
          ElevatedButton(
              onPressed: () => approve(jobId), child: const Text("Onayla")),
        ])
    ]);
  }

  Widget _row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 110, child: Text("$label:")),
        Expanded(
            child: Text(value?.toString() ?? "-",
                style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

/// ===================================================================
/// MOBILE DETAIL BOTTOM SHEET
/// ===================================================================
class _DetailSheet extends StatelessWidget {
  final Map<String, dynamic> job;
  final String jobId;
  final bool canAct;
  final Function(String) approve;
  final Function(String) reject;
  final String Function(String?) nameOf;
  final Color accentColor;


  const _DetailSheet({
    required this.job,
    required this.jobId,
    required this.canAct,
    required this.approve,
    required this.reject,
    required this.nameOf,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 5,
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10)),
        ),
        const SizedBox(height: 16),
        _row("Yük", job['cargoInfo']),
        _row("Şoför", nameOf(job['assignedTo'])),
        _row("Yükleme", job['loadPort']),
        _row("Varış", job['unloadPort']),
        _row("Dispatch", nameOf(job['assignedBy'])),
        const SizedBox(height: 14),
        if (canAct)
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(
                onPressed: () => reject(jobId),
                child:
                    const Text("Reddet", style: TextStyle(color: Colors.red))),
            ElevatedButton(
                onPressed: () => approve(jobId), child: const Text("Onayla")),
          ])
      ]),
    );
  }

  Widget _row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text("$label:", style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(
          value?.toString() ?? "-",
        )),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dispatch_job_detail_page.dart';

class DispatchActiveCompletedPage extends StatefulWidget {
  final String dispatchUid;

  const DispatchActiveCompletedPage({super.key, required this.dispatchUid});

  @override
  State<DispatchActiveCompletedPage> createState() =>
      _DispatchActiveCompletedPageState();
}

class _DispatchActiveCompletedPageState
    extends State<DispatchActiveCompletedPage> {
  final TextEditingController _search = TextEditingController();
  String search = "";

  bool driversLoading = true;

  /// Map: uid -> { name, plateNumber }
  final Map<String, Map<String, dynamic>> drivers = {};

  bool get isDesktop => MediaQuery.of(context).size.width >= 900;
  static const accent = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  // ---------------------------------------------------------------------------
  // 🔹 TÜM ŞOFÖRLERİ YÜKLE (UID tabanlı)
  // ---------------------------------------------------------------------------
  Future<void> _loadDrivers() async {
    final snap = await FirebaseFirestore.instance
        .collection("users")
        .where("role", isEqualTo: "driver")
        .get();

    for (var d in snap.docs) {
      drivers[d.id] = {
        "name": d["name"] ?? "-",
        "plate": d["plateNumber"] ?? "-",
      };
    }

    setState(() => driversLoading = false);
  }

  // ---------------------------------------------------------------------------
  // 🔹 JOBS STREAM (UID tabanlı)
  // ---------------------------------------------------------------------------
  Stream<List<QueryDocumentSnapshot>> _jobs(List<String> statuses) {
    return FirebaseFirestore.instance
        .collection("jobs")
        .where("assignedByUid", isEqualTo: widget.dispatchUid)
        .where("status", whereIn: statuses)
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((s) => s.docs);
  }

  // ---------------------------------------------------------------------------
  // 🔹 STATUS COLOR
  // ---------------------------------------------------------------------------
  Color _statusColor(String status) {
    switch (status) {
      case "approved":
        return Colors.blue;
      case "active":
        return Colors.indigo;
      case "completed":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // ---------------------------------------------------------------------------
  // 🔹 JOB CARD
  // ---------------------------------------------------------------------------
  Widget _jobCard(Map<String, dynamic> j, String jobId) {
    final driverUid = j["assignedToUid"] ?? "";
    final info = drivers[driverUid] ?? {"name": driverUid, "plate": "-"};

    final status = j["status"];
    final sc = _statusColor(status);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DispatchJobDetailPage(
              jobId: jobId,
              data: j,
              canEdit: false,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.local_shipping, color: Colors.grey.shade700),
            ),
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(j["cargoInfo"] ?? "-",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text("Şoför: ${info["name"]} | Plaka: ${info["plate"]}",
                      style:
                      TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                  Text("Yükleme: ${j["loadPort"] ?? "-"}"),
                  Text("Varış: ${j["unloadPort"] ?? "-"}"),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: sc.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                    color: sc, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🔹 JOB LIST BUILDER
  // ---------------------------------------------------------------------------
  Widget _jobList(Stream<List<QueryDocumentSnapshot>> stream) {
    return StreamBuilder(
      stream: stream,
      builder: (_, snap) {
        if (!snap.hasData || driversLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snap.data!;

        // 🔍 SEARCH FILTER (name / plate)
        docs = docs.where((d) {
          final j = d.data() as Map<String, dynamic>;
          final driverUid = j["assignedToUid"];
          final drv = drivers[driverUid];

          if (drv == null) return false;

          final name = drv["name"].toLowerCase();
          final plate = drv["plate"].toLowerCase();

          return name.contains(search) || plate.contains(search);
        }).toList();

        if (docs.isEmpty) {
          return const Center(
              child: Text("Kayıt bulunamadı",
                  style: TextStyle(fontSize: 16, color: Colors.black54)));
        }

        return isDesktop
            ? GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.5,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20),
          itemCount: docs.length,
          itemBuilder: (_, i) =>
              _jobCard(docs[i].data() as Map<String, dynamic>, docs[i].id),
        )
            : ListView.separated(
          padding: const EdgeInsets.all(20),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: docs.length,
          itemBuilder: (_, i) =>
              _jobCard(docs[i].data() as Map<String, dynamic>, docs[i].id),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 🔹 BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const SizedBox(height: 10),

          // SEARCH
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.grey),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (v) =>
                        setState(() => search = v.toLowerCase().trim()),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "İsim veya plaka ile ara...",
                    ),
                  ),
                ),
                if (search.isNotEmpty)
                  IconButton(
                      onPressed: () {
                        _search.clear();
                        setState(() => search = "");
                      },
                      icon: const Icon(Icons.close))
              ],
            ),
          ),

          const SizedBox(height: 16),

          // TAB BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: const TabBar(
              indicatorColor: accent,
              labelColor: accent,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: "Aktif"),
                Tab(text: "Tamamlanan"),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // TAB CONTENT
          Expanded(
            child: Container(
              color: const Color(0xFFF5F6FA),
              child: TabBarView(
                children: [
                  _jobList(_jobs(["approved", "active"])),
                  _jobList(_jobs(["completed"])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

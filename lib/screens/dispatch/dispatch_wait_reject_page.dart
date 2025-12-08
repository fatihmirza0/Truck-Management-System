import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dispatch_job_detail_page.dart';

class DispatchWaitRejectPage extends StatefulWidget {
  final String dispatchUid;

  const DispatchWaitRejectPage({
    super.key,
    required this.dispatchUid,
  });

  @override
  State<DispatchWaitRejectPage> createState() => _DispatchWaitRejectPageState();
}

class _DispatchWaitRejectPageState extends State<DispatchWaitRejectPage> {
  final TextEditingController _search = TextEditingController();
  String search = "";

  bool loadingDrivers = true;

  /// uid -> { name, plate }
  final Map<String, Map<String, String>> drivers = {};

  bool get isDesktop => MediaQuery.of(context).size.width >= 900;
  static const accent = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  // ---------------------------------------------------------------------------
  // ŞOFÖRLERİ UID'YE GÖRE YÜKLE
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

    setState(() => loadingDrivers = false);
  }

  // ---------------------------------------------------------------------------
  // İŞLERİ ÇEK (pending & declined)
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
  // KART
  // ---------------------------------------------------------------------------
  Widget _jobCard(Map<String, dynamic> j, String jobId) {
    final driverUid = j["assignedToUid"] ?? "";
    final info = drivers[driverUid] ?? {"name": "-", "plate": "-"};

    final status = j["status"];
    Color sc = Colors.grey;
    if (status == "pending") sc = Colors.orange;
    if (status == "declined") sc = Colors.red;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DispatchJobDetailPage(
              jobId: jobId,
              data: j,
              canEdit: status == "declined", // reddedilen iş düzenlenebilir
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
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            // Icon
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

            // Text info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(j["cargoInfo"] ?? "-",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    "Şoför: ${info["name"]} | Plaka: ${info["plate"]}",
                    style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  Text("Yükleme: ${j["loadPort"] ?? "-"}"),
                  Text("Varış: ${j["unloadPort"] ?? "-"}"),
                ],
              ),
            ),

            // Status Chip
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: sc.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                    color: sc, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            )
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LİSTE
  // ---------------------------------------------------------------------------
  Widget _jobList(Stream<List<QueryDocumentSnapshot>> stream) {
    return StreamBuilder(
      stream: stream,
      builder: (_, snap) {
        if (!snap.hasData || loadingDrivers) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snap.data!;

        /// Arama filtresi
        docs = docs.where((d) {
          final j = d.data() as Map<String, dynamic>;
          final driverUid = j["assignedToUid"];
          final drv = drivers[driverUid];

          if (drv == null) return false;

          final name = drv["name"]!.toLowerCase();
          final plate = drv["plate"]!.toLowerCase();

          return name.contains(search) || plate.contains(search);
        }).toList();

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "Kayıt bulunamadı",
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          );
        }

        return isDesktop
            ? GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.5,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          itemCount: docs.length,
          itemBuilder: (_, i) => _jobCard(
              docs[i].data() as Map<String, dynamic>, docs[i].id),
        )
            : ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _jobCard(
              docs[i].data() as Map<String, dynamic>, docs[i].id),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
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
                    offset: const Offset(0, 4)),
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
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // TAB
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: const TabBar(
              indicatorColor: accent,
              labelColor: accent,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: "Bekleyen"),
                Tab(text: "Reddedilen"),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // CONTENT
          Expanded(
            child: Container(
              color: const Color(0xFFF5F6FA),
              child: TabBarView(
                children: [
                  _jobList(_jobs(["pending"])),
                  _jobList(_jobs(["declined"])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

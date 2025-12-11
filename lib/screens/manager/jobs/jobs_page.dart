import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'job_detail_panel.dart';
import 'job_service.dart';

// ============================================
// MODERN ENTERPRISE LOGISTICS UI
// + Search & Filter
// + Horizontal Scroll
// + Pagination
// ============================================

class JobsPage extends StatefulWidget {
  const JobsPage({super.key});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();

  String _status = "pending";
  String _searchQuery = "";
  Map<String, dynamic>? _selectedJob;
  String? _selectedId;

  Map<String, String> userCache = {};
  Map<String, String> plateCache = {}; // Plaka cache

  int _currentPage = 1;
  final int _itemsPerPage = 10;

  bool get isDesktop => MediaQuery.of(context).size.width > 900;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _currentPage = 1; // Reset to first page on search
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    userCache.clear();
    plateCache.clear();

    final users = await FirebaseFirestore.instance.collection("users").get();

    for (var doc in users.docs) {
      final data = doc.data();

      userCache[doc.id] = data["name"]?.toString() ?? "-";
      plateCache[doc.id] = data["plateNumber"]?.toString() ?? "-";
    }

    setState(() {});
  }

  String uname(String? id) => userCache[id] ?? "-";

  String plate(String? id) => plateCache[id] ?? "-";

  Stream<QuerySnapshot> _jobsStream() {
    return FirebaseFirestore.instance
        .collection("jobs")
        .where("status", isEqualTo: _status)
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  List<QueryDocumentSnapshot> _filterAndPaginateJobs(
      List<QueryDocumentSnapshot> docs) {
    // Filter by search query
    var filtered = docs.where((doc) {
      if (_searchQuery.isEmpty) return true;

      final job = doc.data() as Map<String, dynamic>;
      final driverName = uname(job["assignedToUid"]).toLowerCase();
      final dispatchName = uname(job["assignedByUid"]).toLowerCase();
      final driverPlate = plate(job["assignedToUid"]).toLowerCase();
      final cargoInfo = (job["cargoInfo"] ?? "").toLowerCase();

      return driverName.contains(_searchQuery) ||
          dispatchName.contains(_searchQuery) ||
          driverPlate.contains(_searchQuery) ||
          cargoInfo.contains(_searchQuery);
    }).toList();

    // Pagination
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;

    if (startIndex >= filtered.length) return [];
    return filtered.sublist(
      startIndex,
      endIndex > filtered.length ? filtered.length : endIndex,
    );
  }

  int _getTotalPages(int totalItems) {
    return (totalItems / _itemsPerPage).ceil();
  }

  void _openDetail(Map<String, dynamic> job, String id) {
    setState(() {
      _selectedJob = job;
      _selectedId = id;
    });

    if (!isDesktop) {
      // 📱 MOBİL → Bottom Sheet göster
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.6,
            maxChildSize: 0.95,
            builder: (_, controller) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: JobDetailPanel(
                  job: job,
                  jobId: id,
                  uname: uname,
                  onApprove: () {
                    JobService.approveJob(id);
                    Navigator.pop(context);
                  },
                  onReject: () {
                    JobService.rejectJob(id);
                    Navigator.pop(context);
                  },
                ),
              );
            },
          );
        },
      );
    } else {
      // 💻 DESKTOP → Drawer aç
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scaffoldKey.currentState?.openEndDrawer();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      endDrawer: _selectedJob == null
          ? null
          : JobDetailPanel(
              job: _selectedJob!,
              jobId: _selectedId!,
              uname: uname,
              onApprove: () => JobService.approveJob(_selectedId!),
              onReject: () => JobService.rejectJob(_selectedId!),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modern Header with Icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A5F).withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "İş Yönetimi",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E3A5F),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Tüm nakliye operasyonlarını takip edin",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Search Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: "Şoför adı, dispatch, plaka veya yük ile ara...",
                    hintStyle: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(Icons.search, color: Color(0xFF64748B)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Premium Segmented Control
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),

                // 🔥 Overflow'u çözen satır:
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTabButton(
                          "pending", "Onay Bekleyen", Icons.pending_outlined),
                      _buildTabButton(
                          "approved", "Yolda", Icons.local_shipping_outlined),
                      _buildTabButton(
                          "completed", "Tamamlanan", Icons.check_circle_outline),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _jobsStream(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Color(0xFF1E3A5F)),
                        ),
                      );
                    }

                    final allDocs = snap.data!.docs;
                    final filtered = _filterAndPaginateJobs(allDocs);

                    if (allDocs.isEmpty) {
                      return _buildEmptyState();
                    }

                    if (_searchQuery.isNotEmpty && filtered.isEmpty) {
                      return _buildNoResultsState();
                    }

                    return Column(
                      children: [
                        Expanded(
                          child: isDesktop
                              ? _buildDesktopTable(filtered)
                              : _buildMobileList(filtered),
                        ),
                        // Pagination
                        if (allDocs.isNotEmpty)
                          _buildPagination(
                            _searchQuery.isEmpty
                                ? allDocs.length
                                : allDocs.where((doc) {
                                    final job =
                                        doc.data() as Map<String, dynamic>;
                                    final driverName =
                                        uname(job["assignedToUid"])
                                            .toLowerCase();
                                    final dispatchName =
                                        uname(job["assignedByUid"])
                                            .toLowerCase();
                                    final driverPlate =
                                        plate(job["assignedToUid"])
                                            .toLowerCase();
                                    final cargoInfo =
                                        (job["cargoInfo"] ?? "").toLowerCase();
                                    return driverName.contains(_searchQuery) ||
                                        dispatchName.contains(_searchQuery) ||
                                        driverPlate.contains(_searchQuery) ||
                                        cargoInfo.contains(_searchQuery);
                                  }).length,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String key, String label, IconData icon) {
    final selected = _status == key;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _status = key;
              _currentPage = 1; // Reset page on status change
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF1E3A5F) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.white : const Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
            "Henüz İş Yok",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Bu kategoride görüntülenecek iş bulunmuyor",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
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
              Icons.search_off_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Sonuç Bulunamadı",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Aramanızla eşleşen iş bulunamadı",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(int totalItems) {
    final totalPages = _getTotalPages(totalItems);
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Toplam $totalItems sonuç",
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
                icon: const Icon(Icons.chevron_left),
                color: const Color(0xFF1E3A5F),
                disabledColor: const Color(0xFFCBD5E0),
              ),
              ...List.generate(
                totalPages > 5 ? 5 : totalPages,
                (index) {
                  int pageNum;
                  if (totalPages <= 5) {
                    pageNum = index + 1;
                  } else if (_currentPage <= 3) {
                    pageNum = index + 1;
                  } else if (_currentPage >= totalPages - 2) {
                    pageNum = totalPages - 4 + index;
                  } else {
                    pageNum = _currentPage - 2 + index;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Material(
                      color: _currentPage == pageNum
                          ? const Color(0xFF1E3A5F)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => setState(() => _currentPage = pageNum),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Text(
                            pageNum.toString(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _currentPage == pageNum
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
                icon: const Icon(Icons.chevron_right),
                color: const Color(0xFF1E3A5F),
                disabledColor: const Color(0xFFCBD5E0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(List<QueryDocumentSnapshot> docs) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1200),
            child: DataTable(
              headingRowColor:
                  MaterialStateProperty.all(const Color(0xFFF8FAFC)),
              headingRowHeight: 56,
              dataRowHeight: 64,
              horizontalMargin: 24,
              columnSpacing: 48,
              dividerThickness: 1,
              columns: [
                _buildColumn("Yük Bilgisi", Icons.inventory_2_outlined),
                _buildColumn("Şoför", Icons.person_outline),
                _buildColumn("Plaka", Icons.car_rental_outlined),
                _buildColumn("Yükleme", Icons.location_on_outlined),
                _buildColumn("Varış", Icons.flag_outlined),
                _buildColumn("Dispatch", Icons.support_agent_outlined),
                _buildColumn("İşlemler", Icons.more_horiz),
              ],
              rows: docs.map((d) {
                final j = d.data() as Map<String, dynamic>;

                return DataRow(
                  cells: [
                    _buildDataCell(
                        j["cargoInfo"], false, () => _openDetail(j, d.id)),
                    _buildDataCell(uname(j["assignedToUid"]), false,
                        () => _openDetail(j, d.id)),
                    _buildDataCell(plate(j["assignedToUid"]), false,
                        () => _openDetail(j, d.id)),
                    _buildDataCell(
                        j["loadPort"], false, () => _openDetail(j, d.id)),
                    _buildDataCell(
                        j["unloadPort"], false, () => _openDetail(j, d.id)),
                    _buildDataCell(uname(j["assignedByUid"]), false,
                        () => _openDetail(j, d.id)),
                    DataCell(
                      Row(
                        children: [
                          _buildActionButton(
                            Icons.visibility_outlined,
                            const Color(0xFF64748B),
                            () => _openDetail(j, d.id),
                          ),
                          if (_status == "pending") ...[
                            const SizedBox(width: 8),
                            _buildActionButton(
                              Icons.check_circle_outline,
                              const Color(0xFF059669),
                              () => JobService.approveJob(d.id),
                            ),
                            const SizedBox(width: 8),
                            _buildActionButton(
                              Icons.cancel_outlined,
                              const Color(0xFFDC2626),
                              () => JobService.rejectJob(d.id),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  DataColumn _buildColumn(String label, IconData icon) {
    return DataColumn(
      label: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  DataCell _buildDataCell(dynamic text, bool isBold, VoidCallback onTap) {
    return DataCell(
      GestureDetector(
        onTap: onTap,
        child: Text(
          text?.toString() ?? "-",
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            color: isBold ? const Color(0xFF0F172A) : const Color(0xFF475569),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildActionButton(
      IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18),
        color: color,
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }

  Widget _buildMobileList(List<QueryDocumentSnapshot> docs) {
    return ListView.separated(
      itemCount: docs.length,
      padding: const EdgeInsets.only(bottom: 32),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final d = docs[index];
        final j = d.data() as Map<String, dynamic>;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openDetail(j, d.id),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            size: 20,
                            color: Color(0xFF1E3A5F),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            j["cargoInfo"] ?? "-",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildMobileInfoRow(
                      Icons.person_outline,
                      "Şoför",
                      uname(j["assignedToUid"]),
                    ),
                    const SizedBox(height: 8),
                    _buildMobileInfoRow(
                      Icons.car_rental_outlined,
                      "Plaka",
                      plate(j["assignedToUid"]),
                    ),
                    const SizedBox(height: 8),
                    _buildMobileInfoRow(
                      Icons.location_on_outlined,
                      "Güzergah",
                      "${j["loadPort"]} → ${j["unloadPort"]}",
                    ),
                    if (_status == "pending") ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => JobService.rejectJob(d.id),
                              icon: const Icon(Icons.cancel_outlined, size: 18),
                              label: const Text("Reddet"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                side: const BorderSide(
                                  color: Color(0xFFDC2626),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => JobService.approveJob(d.id),
                              icon: const Icon(Icons.check_circle_outline,
                                  size: 18),
                              label: const Text("Onayla"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

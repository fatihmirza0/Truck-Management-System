import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../job_detail_panel.dart';
import '../job_service.dart';
import '../widgets/jobs_page_header.dart';
import '../widgets/jobs_search_bar.dart';

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

  // Cache maps
  Map<String, Map<String, dynamic>> userCache = {};
  Map<String, Map<String, dynamic>> vehicleCache = {};

  int _currentPage = 1;
  final int _itemsPerPage = 10;

  bool get isDesktop => MediaQuery.of(context).size.width > 900;

  @override
  void initState() {
    super.initState();
    _loadCacheData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _currentPage = 1;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCacheData() async {
    userCache.clear();
    vehicleCache.clear();

    // Load users
    final users = await FirebaseFirestore.instance
        .collection("users")
        .where("softDeleted", isEqualTo: false)
        .get();

    for (var doc in users.docs) {
      userCache[doc.id] = doc.data();
    }

    // Load vehicles
    final vehicles = await FirebaseFirestore.instance
        .collection("vehicles")
        .where("isActive", isEqualTo: true)
        .get();

    for (var doc in vehicles.docs) {
      vehicleCache[doc.id] = doc.data();
    }

    setState(() {});
  }

  String userName(String? uid) {
    if (uid == null) return "-";
    return userCache[uid]?["name"] ?? "-";
  }

  String vehiclePlate(String? vehicleId) {
    if (vehicleId == null) return "-";
    return vehicleCache[vehicleId]?["plate"] ?? "-";
  }

  Stream<QuerySnapshot> _jobsStream() {
    return FirebaseFirestore.instance
        .collection("jobs")
        .where("softDeleted", isEqualTo: false)
        .where("status", isEqualTo: _status)
        .orderBy("timestamps.createdAt", descending: true)
        .snapshots();
  }

  List<QueryDocumentSnapshot> _filterAndPaginateJobs(
      List<QueryDocumentSnapshot> docs) {
    // Filter by search query
    var filtered = docs.where((doc) {
      if (_searchQuery.isEmpty) return true;

      final job = doc.data() as Map<String, dynamic>;
      final driverName = userName(job["driverId"]).toLowerCase();
      final dispatchName = userName(job["createdBy"]).toLowerCase();
      final vehiclePlateNo = vehiclePlate(job["vehicleId"]).toLowerCase();
      final referenceNo = (job["referenceNo"] ?? "").toLowerCase();
      final cargoType = (job["cargo"]?["type"] ?? "").toLowerCase();
      final cargoDesc = (job["cargo"]?["description"] ?? "").toLowerCase();
      final loadPort = (job["route"]?["loadPort"] ?? "").toLowerCase();
      final unloadPort = (job["route"]?["unloadPort"] ?? "").toLowerCase();

      return driverName.contains(_searchQuery) ||
          dispatchName.contains(_searchQuery) ||
          vehiclePlateNo.contains(_searchQuery) ||
          referenceNo.contains(_searchQuery) ||
          cargoType.contains(_searchQuery) ||
          cargoDesc.contains(_searchQuery) ||
          loadPort.contains(_searchQuery) ||
          unloadPort.contains(_searchQuery);
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
                  userName: userName,
                  vehiclePlate: vehiclePlate,
                  onApprove: () async {
                    await JobService.approveJob(_selectedId!);
                    _closeDetailPanel();
                  },
                  onReject: (reason) async {
                    await JobService.rejectJob(_selectedId!, reason);
                    _closeDetailPanel();
                  },
                ),
              );
            },
          );
        },
      );
    } else {
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
              userName: userName,
              vehiclePlate: vehiclePlate,
              onApprove: () async {
                await JobService.approveJob(_selectedId!);
                _closeDetailPanel();
              },
              onReject: (reason) async {
                await JobService.rejectJob(_selectedId!, reason);
                _closeDetailPanel();
              },
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modern Header
              const JobsPageHeader(),
              const SizedBox(height: 24),

              // Search Bar
              JobsSearchBar(controller: _searchController),
              const SizedBox(height: 20),

              // Status Tabs
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTabButton(
                          "pending", "Onay Bekleyen", Icons.pending_outlined),
                      _buildTabButton(
                          "rejected", "Reddedilen", Icons.cancel_outlined),
                      _buildTabButton(
                          "approved", "Onaylanan", Icons.check_circle_outline),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

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
                        if (allDocs.isNotEmpty)
                          _buildPagination(
                            _searchQuery.isEmpty
                                ? allDocs.length
                                : allDocs.where((doc) {
                                    final job =
                                        doc.data() as Map<String, dynamic>;
                                    final driverName =
                                        userName(job["driverId"]).toLowerCase();
                                    final dispatchName =
                                        userName(job["createdBy"])
                                            .toLowerCase();
                                    final vehiclePlateNo =
                                        vehiclePlate(job["vehicleId"])
                                            .toLowerCase();
                                    final referenceNo =
                                        (job["referenceNo"] ?? "")
                                            .toLowerCase();
                                    final cargoType =
                                        (job["cargo"]?["type"] ?? "")
                                            .toLowerCase();
                                    final cargoDesc =
                                        (job["cargo"]?["description"] ?? "")
                                            .toLowerCase();
                                    return driverName.contains(_searchQuery) ||
                                        dispatchName.contains(_searchQuery) ||
                                        vehiclePlateNo.contains(_searchQuery) ||
                                        referenceNo.contains(_searchQuery) ||
                                        cargoType.contains(_searchQuery) ||
                                        cargoDesc.contains(_searchQuery);
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
      padding: const EdgeInsets.only(right: 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _status = key;
              _currentPage = 1;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 20 : 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF1E3A5F) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.white : const Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
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
            color: Colors.black.withValues(alpha: 0.03),
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
                  WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              headingRowHeight: 56,
              dataRowHeight: 64,
              horizontalMargin: 24,
              columnSpacing: 48,
              dividerThickness: 1,
              columns: [
                _buildColumn("Referans No", Icons.tag),
                _buildColumn("Şoför", Icons.person_outline),
                _buildColumn("Plaka", Icons.car_rental_outlined),
                _buildColumn("Yük Tipi", Icons.inventory_2_outlined),
                _buildColumn("Güzergah", Icons.route_outlined),
                _buildColumn("Ağırlık (kg)", Icons.scale_outlined),
                _buildColumn("Dispatch", Icons.support_agent_outlined),
                _buildColumn("İşlemler", Icons.more_horiz),
              ],
              rows: docs.map((d) {
                final j = d.data() as Map<String, dynamic>;
                final cargo = j["cargo"] as Map<String, dynamic>?;
                final route = j["route"] as Map<String, dynamic>?;
                final jobStatus = j["status"];

                return DataRow(
                  cells: [
                    _buildDataCell(
                        j["referenceNo"], false, () => _openDetail(j, d.id)),
                    _buildDataCell(userName(j["driverId"]), false,
                        () => _openDetail(j, d.id)),
                    _buildDataCell(vehiclePlate(j["vehicleId"]), false,
                        () => _openDetail(j, d.id)),
                    _buildDataCell(
                        cargo?["type"], false, () => _openDetail(j, d.id)),
                    _buildDataCell(
                        "${route?["loadPort"] ?? "-"} → ${route?["unloadPort"] ?? "-"}",
                        false,
                        () => _openDetail(j, d.id)),
                    _buildDataCell(
                        cargo?["weightKg"], false, () => _openDetail(j, d.id)),
                    _buildDataCell(userName(j["createdBy"]), false,
                        () => _openDetail(j, d.id)),
                    DataCell(
                      Row(
                        children: [
                          _buildActionButton(
                            Icons.visibility_outlined,
                            const Color(0xFF64748B),
                            () => _openDetail(j, d.id),
                          ),
                          if (jobStatus == "pending") ...[
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
                              () => _showRejectDialog(d.id),
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
        color: color.withValues(alpha: 0.1),
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
        final cargo = j["cargo"] as Map<String, dynamic>?;
        final route = j["route"] as Map<String, dynamic>?;
        final jobStatus = j["status"];

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
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
                            Icons.tag,
                            size: 20,
                            color: Color(0xFF1E3A5F),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            j["referenceNo"] ?? "-",
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
                      userName(j["driverId"]),
                    ),
                    const SizedBox(height: 8),
                    _buildMobileInfoRow(
                      Icons.car_rental_outlined,
                      "Plaka",
                      vehiclePlate(j["vehicleId"]),
                    ),
                    const SizedBox(height: 8),
                    _buildMobileInfoRow(
                      Icons.inventory_2_outlined,
                      "Yük",
                      "${cargo?["type"] ?? "-"} (${cargo?["weightKg"] ?? 0} kg)",
                    ),
                    const SizedBox(height: 8),
                    _buildMobileInfoRow(
                      Icons.location_on_outlined,
                      "Güzergah",
                      "${route?["loadPort"] ?? "-"} → ${route?["unloadPort"] ?? "-"}",
                    ),
                    if (jobStatus == "pending") ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showRejectDialog(d.id),
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

  void _showRejectDialog(String jobId) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("İşi Reddet"),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: "Red Nedeni",
            hintText: "Lütfen red sebebini yazın...",
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Lütfen red nedeni belirtin"),
                  ),
                );
                return;
              }
              JobService.rejectJob(jobId, reasonController.text.trim());
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text("Reddet"),
          ),
        ],
      ),
    );
  }

  void _closeDetailPanel() {
    // Drawer açık mı kontrol et
    if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeEndDrawer();
    }

    // Mobile bottom sheet ise
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    setState(() {
      _selectedJob = null;
      _selectedId = null;
    });
  }
}




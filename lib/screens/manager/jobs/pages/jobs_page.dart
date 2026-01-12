import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:lojistik/screens/manager/jobs/job_service.dart';
import 'package:lojistik/screens/manager/jobs/widgets/jobs_page_header.dart';
import 'package:lojistik/screens/manager/jobs/widgets/jobs_search_bar.dart';
import 'package:lojistik/screens/manager/jobs/widgets/job_card.dart';
import 'package:lojistik/screens/manager/jobs/pages/manager_job_detail_page.dart';
import 'package:lojistik/config/app_theme.dart';
import 'package:lojistik/widgets/animated/animated_widgets.dart';

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

  void _navigateToDetail(Map<String, dynamic> job, String id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManagerJobDetailPage(
          jobId: id,
          data: job,
          driverName: userName(job['driverId']),
          vehiclePlate: vehiclePlate(job['vehicleId']),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modern Header
              JobsPageHeader(isDesktop: isDesktop),
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
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: AppTheme.softShadow,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTabButton(
                          "pending", "Onay Bekleyen", Icons.pending_actions_rounded),
                      const SizedBox(width: 4),
                      _buildTabButton(
                          "rejected", "Reddedilen", Icons.cancel_outlined),
                      const SizedBox(width: 4),
                      _buildTabButton(
                          "approved", "Onaylanan", Icons.check_circle_outline),
                      const SizedBox(width: 4),
                      _buildTabButton(
                          "completed", "Tamamlanan", Icons.done_all_rounded),
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
                          valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
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
                          child: _buildJobsGrid(filtered),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _status = key;
            _currentPage = 1;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 14 : 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF2D4A6F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF1E3A5F).withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobsGrid(List<QueryDocumentSnapshot> docs) {
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = 1;
    if (width > 1600) {
      crossAxisCount = 4;
    } else if (width > 1100) {
      crossAxisCount = 3;
    } else if (width > 700) {
      crossAxisCount = 2;
    }

    return GridView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        mainAxisExtent: _status == "pending" ? 300 : 250,
      ),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final d = docs[index];
        final j = d.data() as Map<String, dynamic>;

        return JobCard(
          job: j,
          jobId: d.id,
          userName: userName,
          vehiclePlate: vehiclePlate,
          onTap: () => _navigateToDetail(j, d.id),
          onApprove: () => JobService.approveJob(d.id),
          onReject: () => _navigateToDetail(j, d.id),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: AppTheme.softShadow,
            ),
            child: Icon(
              Icons.inbox_rounded,
              size: 64,
              color: AppTheme.textTertiary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Henüz İş Bulunmuyor",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Bu kategoride görüntülenecek herhangi bir kayıt bulunamadı.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
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
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: AppTheme.softShadow,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 64,
              color: AppTheme.textTertiary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Sonuç Bulunamadı",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "\"$_searchQuery\" araması için uygun kayıt bulunamadı.",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => _searchController.clear(),
            child: const Text("Aramayı Temizle"),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(int totalItems) {
    final totalPages = _getTotalPages(totalItems);
    if (totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Toplam $totalItems sonuç",
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              _buildPageNavButton(
                Icons.chevron_left_rounded,
                _currentPage > 1 ? () => setState(() => _currentPage--) : null,
              ),
              const SizedBox(width: 8),
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

                  final isSelected = _currentPage == pageNum;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ScaleButton(
                      onTap: () => setState(() => _currentPage = pageNum),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryColor : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: isSelected ? AppTheme.softShadow : null,
                        ),
                        child: Center(
                          child: Text(
                            pageNum.toString(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildPageNavButton(
                Icons.chevron_right_rounded,
                _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageNavButton(IconData icon, VoidCallback? onTap) {
    return ScaleButton(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Icon(
          icon,
          size: 20,
          color: onTap != null ? AppTheme.textPrimary : AppTheme.textTertiary,
        ),
      ),
    );
  }

}




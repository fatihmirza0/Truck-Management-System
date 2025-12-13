import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dispatch_job_detail_page.dart';

class DispatchJobsPage extends StatefulWidget {
  final String dispatchUid;

  const DispatchJobsPage({
    super.key,
    required this.dispatchUid,
  });

  @override
  State<DispatchJobsPage> createState() => _DispatchJobsPageState();
}

class _DispatchJobsPageState extends State<DispatchJobsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedTab = "pending"; // pending, declined, approved, completed

  bool loadingDrivers = true;
  final Map<String, Map<String, String>> drivers = {};

  bool get isDesktop => MediaQuery.of(context).size.width > 900;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  Stream<QuerySnapshot> _jobsStream() {
    return FirebaseFirestore.instance
        .collection("jobs")
        .where("assignedByUid", isEqualTo: widget.dispatchUid)
        .where("status", isEqualTo: _selectedTab)
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  List<QueryDocumentSnapshot> _filterJobs(List<QueryDocumentSnapshot> docs) {
    if (_searchQuery.isEmpty) return docs;

    return docs.where((d) {
      final j = d.data() as Map<String, dynamic>;
      final driverUid = j["assignedToUid"];
      final drv = drivers[driverUid];

      if (drv == null) return false;

      final name = drv["name"]!.toLowerCase();
      final plate = drv["plate"]!.toLowerCase();
      final cargoInfo = (j["cargoInfo"] ?? "").toLowerCase();
      final loadPort = (j["loadPort"] ?? "").toLowerCase();
      final unloadPort = (j["unloadPort"] ?? "").toLowerCase();

      return name.contains(_searchQuery) ||
          plate.contains(_searchQuery) ||
          cargoInfo.contains(_searchQuery) ||
          loadPort.contains(_searchQuery) ||
          unloadPort.contains(_searchQuery);
    }).toList();
  }

  void _openDetail(Map<String, dynamic> job, String jobId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DispatchJobDetailPage(
          jobId: jobId,
          data: job,
          canEdit: job["status"] == "declined",
        ),
      ),
    );
  }

  String _getPageTitle() {
    switch (_selectedTab) {
      case "pending":
        return "Bekleyen İşler";
      case "declined":
        return "Reddedilen İşler";
      case "approved":
        return "Yoldaki İşler";
      case "completed":
        return "Tamamlanan İşler";
      default:
        return "İş Takibi";
    }
  }

  String _getPageSubtitle() {
    switch (_selectedTab) {
      case "pending":
        return "Onay bekleyen işleriniz";
      case "declined":
        return "Şoförler tarafından reddedilen işler";
      case "approved":
        return "Şu anda devam eden işler";
      case "completed":
        return "Başarıyla tamamlanan işler";
      default:
        return "Tüm işleriniz";
    }
  }

  IconData _getPageIcon() {
    switch (_selectedTab) {
      case "pending":
        return Icons.pending_outlined;
      case "declined":
        return Icons.cancel_outlined;
      case "approved":
        return Icons.local_shipping_outlined;
      case "completed":
        return Icons.check_circle_outline;
      default:
        return Icons.assignment_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dynamic Header
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
                    child: Icon(
                      _getPageIcon(),
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getPageTitle(),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E3A5F),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getPageSubtitle(),
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
                    hintText: "Şoför adı, plaka veya yük ile ara...",
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

              // Four Tab Buttons
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
                child: isDesktop
                    ? Row(
                  children: [
                    Expanded(
                      child: _buildTabButton(
                        "pending",
                        "Bekleyen",
                        Icons.pending_outlined,
                      ),
                    ),
                    Expanded(
                      child: _buildTabButton(
                        "declined",
                        "Reddedilen",
                        Icons.cancel_outlined,
                      ),
                    ),
                    Expanded(
                      child: _buildTabButton(
                        "approved",
                        "Yolda",
                        Icons.local_shipping_outlined,
                      ),
                    ),
                    Expanded(
                      child: _buildTabButton(
                        "completed",
                        "Tamamlanan",
                        Icons.check_circle_outline,
                      ),
                    ),
                  ],
                )
                    : Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTabButton(
                            "pending",
                            "Bekleyen",
                            Icons.pending_outlined,
                          ),
                        ),
                        Expanded(
                          child: _buildTabButton(
                            "declined",
                            "Reddedilen",
                            Icons.cancel_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTabButton(
                            "approved",
                            "Yolda",
                            Icons.local_shipping_outlined,
                          ),
                        ),
                        Expanded(
                          child: _buildTabButton(
                            "completed",
                            "Tamamlanan",
                            Icons.check_circle_outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _jobsStream(),
                  builder: (context, snap) {
                    if (!snap.hasData || loadingDrivers) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Color(0xFF1E3A5F)),
                        ),
                      );
                    }

                    final allDocs = snap.data!.docs;
                    final filtered = _filterJobs(allDocs);

                    if (allDocs.isEmpty) {
                      return _buildEmptyState();
                    }

                    if (_searchQuery.isNotEmpty && filtered.isEmpty) {
                      return _buildNoResultsState();
                    }

                    return isDesktop
                        ? _buildDesktopGrid(filtered)
                        : _buildMobileList(filtered);
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
    final selected = _selectedTab == key;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = key;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1E3A5F) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
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

  Widget _buildDesktopGrid(List<QueryDocumentSnapshot> docs) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final d = docs[index];
        final j = d.data() as Map<String, dynamic>;
        return _buildJobCard(j, d.id);
      },
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
        return _buildJobCard(j, d.id);
      },
    );
  }

  Widget _buildJobCard(Map<String, dynamic> j, String jobId) {
    final driverUid = j["assignedToUid"] ?? "";
    final info = drivers[driverUid] ?? {"name": "-", "plate": "-"};
    final status = j["status"];

    Color statusColor = Colors.grey;
    String statusText = "";
    IconData statusIcon = Icons.info_outline;

    switch (status) {
      case "pending":
        statusColor = const Color(0xFFF59E0B);
        statusText = "BEKLEYEN";
        statusIcon = Icons.pending_outlined;
        break;
      case "declined":
        statusColor = const Color(0xFFDC2626);
        statusText = "REDDEDİLDİ";
        statusIcon = Icons.cancel_outlined;
        break;
      case "approved":
        statusColor = const Color(0xFF3B82F6);
        statusText = "YOLDA";
        statusIcon = Icons.local_shipping_outlined;
        break;
      case "completed":
        statusColor = const Color(0xFF059669);
        statusText = "TAMAMLANDI";
        statusIcon = Icons.check_circle;
        break;
    }

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
          onTap: () => _openDetail(j, jobId),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            statusIcon,
                            size: 14,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  Icons.person_outline,
                  "Şoför",
                  info["name"]!,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.car_rental_outlined,
                  "Plaka",
                  info["plate"]!,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.location_on_outlined,
                  "Güzergah",
                  "${j["loadPort"]} → ${j["unloadPort"]}",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
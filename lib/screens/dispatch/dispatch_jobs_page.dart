import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lojistik/services/firestore_service.dart';
import 'dispatch_job_detail_page.dart';

class DispatchJobsPage extends StatefulWidget {
  const DispatchJobsPage({super.key});

  @override
  State<DispatchJobsPage> createState() => _DispatchJobsPageState();
}

class _DispatchJobsPageState extends State<DispatchJobsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedStatus = FirestoreService.statusPending;

  bool _loading = true;
  final Map<String, String> _driverNameCache = {};
  final Map<String, String> _vehiclePlateCache = {};

  bool get isDesktop => MediaQuery.of(context).size.width > 900;

  @override
  void initState() {
    super.initState();
    _loadCaches();
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

  Future<void> _loadCaches() async {
    try {
      final driverCache = await FirestoreService.fetchDriverCache();
      final vehicleCache = await FirestoreService.fetchVehicleCache();

      setState(() {
        _driverNameCache.addAll(driverCache);
        _vehiclePlateCache.addAll(vehicleCache);
        _loading = false;
      });
    } catch (e) {
      print('Cache load error: $e');
      setState(() => _loading = false);
    }
  }

  Stream<QuerySnapshot> _jobsStream() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      return const Stream.empty();
    }

    return FirestoreService.getDispatchJobsStream(
      userId: currentUid,
      status: _selectedStatus,
    );
  }

  List<QueryDocumentSnapshot> _filterJobs(List<QueryDocumentSnapshot> docs) {
    if (_searchQuery.isEmpty) return docs;

    return docs.where((doc) {
      final job = doc.data() as Map<String, dynamic>;

      // Driver bilgileri
      final driverId = job["driverId"];
      final driverName = _driverNameCache[driverId]?.toLowerCase() ?? "";

      // Vehicle bilgileri
      final vehicleId = job["vehicleId"];
      final vehiclePlate = _vehiclePlateCache[vehicleId]?.toLowerCase() ?? "";

      // Route bilgileri
      final route = job["route"] as Map<String, dynamic>? ?? {};
      final loadPort = route["loadPort"]?.toString().toLowerCase() ?? "";
      final unloadPort = route["unloadPort"]?.toString().toLowerCase() ?? "";

      // Cargo bilgileri
      final cargo = job["cargo"] as Map<String, dynamic>? ?? {};
      final cargoType = cargo["type"]?.toString().toLowerCase() ?? "";
      final cargoDesc = cargo["description"]?.toString().toLowerCase() ?? "";

      // Reference No
      final refNo = job["referenceNo"]?.toString().toLowerCase() ?? "";

      return driverName.contains(_searchQuery) ||
          vehiclePlate.contains(_searchQuery) ||
          loadPort.contains(_searchQuery) ||
          unloadPort.contains(_searchQuery) ||
          cargoType.contains(_searchQuery) ||
          cargoDesc.contains(_searchQuery) ||
          refNo.contains(_searchQuery);
    }).toList();
  }

  void _openDetail(Map<String, dynamic> job, String jobId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DispatchJobDetailPage(
          jobId: jobId,
          data: job,
          // canEdit: job["status"] == FirestoreService.statusPending,
          driverName: _driverNameCache[job["driverId"]] ?? "Bilinmiyor",
          vehiclePlate: _vehiclePlateCache[job["vehicleId"]] ?? "Bilinmiyor",
        ),
      ),
    );
  }

  String _getPageTitle() {
    switch (_selectedStatus) {
      case FirestoreService.statusPending:
        return "Bekleyen İşler";
      case FirestoreService.statusRejected:
        return "Reddedilen İşler";
      case FirestoreService.statusApproved:
        return "Yoldaki İşler";
      case FirestoreService.statusCompleted:
        return "Tamamlanan İşler";
      default:
        return "İş Takibi";
    }
  }

  String _getPageSubtitle() {
    switch (_selectedStatus) {
      case FirestoreService.statusPending:
        return "Onay bekleyen işleriniz";
      case FirestoreService.statusRejected:
        return "Şoförler tarafından reddedilen işler";
      case FirestoreService.statusApproved:
        return "Onaylanmış ve yolda olan işler";
      case FirestoreService.statusCompleted:
        return "Başarıyla tamamlanan işler";
      default:
        return "Tüm işleriniz";
    }
  }

  IconData _getPageIcon() {
    switch (_selectedStatus) {
      case FirestoreService.statusPending:
        return Icons.pending_outlined;
      case FirestoreService.statusRejected:
        return Icons.cancel_outlined;
      case FirestoreService.statusApproved:
        return Icons.local_shipping_outlined;
      case FirestoreService.statusCompleted:
        return Icons.check_circle;
      default:
        return Icons.assignment_outlined;
    }
  }

  Widget _buildStatusTabButton(String status, String label, IconData icon) {
    final selected = _selectedStatus == status;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedStatus = status;
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
                    hintText: "Şoför, plaka, yük veya güzergah ile ara...",
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

              // Status Tabs
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
                    // Pending
                    Expanded(
                      child: _buildStatusTabButton(
                        FirestoreService.statusPending,
                        "Bekleyen",
                        Icons.pending_outlined,
                      ),
                    ),
                    // Rejected
                    Expanded(
                      child: _buildStatusTabButton(
                        FirestoreService.statusRejected,
                        "Reddedilen",
                        Icons.cancel_outlined,
                      ),
                    ),
                    // Approved (Yolda)
                    Expanded(
                      child: _buildStatusTabButton(
                        FirestoreService.statusApproved,
                        "Yolda",
                        Icons.local_shipping_outlined,
                      ),
                    ),
                    // Completed
                    Expanded(
                      child: _buildStatusTabButton(
                        FirestoreService.statusCompleted,
                        "Tamamlanan",
                        Icons.check_circle,
                      ),
                    ),
                  ],
                )
                    : Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatusTabButton(
                            FirestoreService.statusPending,
                            "Bekleyen",
                            Icons.pending_outlined,
                          ),
                        ),
                        Expanded(
                          child: _buildStatusTabButton(
                            FirestoreService.statusRejected,
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
                          child: _buildStatusTabButton(
                            FirestoreService.statusApproved,
                            "Yolda",
                            Icons.local_shipping_outlined,
                          ),
                        ),
                        Expanded(
                          child: _buildStatusTabButton(
                            FirestoreService.statusCompleted,
                            "Tamamlanan",
                            Icons.check_circle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Jobs List/Grid
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _jobsStream(),
                  builder: (context, snapshot) {
                    if (_loading) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Color(0xFF1E3A5F)),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Color(0xFF1E3A5F)),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState();
                    }

                    final allDocs = snapshot.data!.docs;
                    final filtered = _filterJobs(allDocs);

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

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
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
        final doc = docs[index];
        final job = doc.data() as Map<String, dynamic>;
        return _buildJobCard(job, doc.id);
      },
    );
  }

  Widget _buildMobileList(List<QueryDocumentSnapshot> docs) {
    return ListView.separated(
      itemCount: docs.length,
      padding: const EdgeInsets.only(bottom: 32),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final doc = docs[index];
        final job = doc.data() as Map<String, dynamic>;
        return _buildJobCard(job, doc.id);
      },
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job, String jobId) {
    final status = job["status"];
    final statusColor = FirestoreService.getStatusColor(status);
    final statusText = FirestoreService.getStatusText(status);

    final driverId = job["driverId"];
    final driverName = _driverNameCache[driverId] ?? "Bilinmiyor";

    final vehicleId = job["vehicleId"];
    final vehiclePlate = _vehiclePlateCache[vehicleId] ?? "Bilinmiyor";

    final route = job["route"] as Map<String, dynamic>? ?? {};
    final loadPort = route["loadPort"] ?? "-";
    final unloadPort = route["unloadPort"] ?? "-";

    final cargo = job["cargo"] as Map<String, dynamic>? ?? {};
    final cargoType = cargo["type"] ?? "-";
    final cargoWeight = cargo["weightKg"] != null
        ? "${cargo["weightKg"]} kg"
        : "-";

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
          onTap: () => _openDetail(job, jobId),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Ref No and Status
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job["referenceNo"] ?? "REF-XXX",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E3A5F),
                            ),
                          ),
                          Text(
                            cargoType,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
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
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Driver Info
                _buildInfoRow(
                  Icons.person_outline,
                  "Şoför",
                  driverName,
                ),
                const SizedBox(height: 8),

                // Vehicle Info
                _buildInfoRow(
                  Icons.local_shipping_outlined,
                  "Araç",
                  vehiclePlate,
                ),
                const SizedBox(height: 8),

                // Route Info
                _buildInfoRow(
                  Icons.route_outlined,
                  "Güzergah",
                  "$loadPort → $unloadPort",
                ),
                const SizedBox(height: 8),

                // Cargo Weight
                _buildInfoRow(
                  Icons.scale_outlined,
                  "Ağırlık",
                  cargoWeight,
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
// 📁 lib/pages/dispatch_jobs_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lojistik/services/firestore_Service.dart';
import 'package:lojistik/screens/dispatch/dispatch_job_detail_page.dart';
import '../../../widgets/empty_state.dart' hide EmptyState;
import 'widgets/jobs_page_header.dart';
import 'widgets/jobs_search_bar.dart';
import 'widgets/jobs_status_tabs.dart';
import 'widgets/job_card.dart';
import 'widgets/empty_state.dart';

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

      final driverId = job["driverId"];
      final driverName = _driverNameCache[driverId]?.toLowerCase() ?? "";

      final vehicleId = job["vehicleId"];
      final vehiclePlate = _vehiclePlateCache[vehicleId]?.toLowerCase() ?? "";

      final route = job["route"] as Map<String, dynamic>? ?? {};
      final loadPort = route["loadPort"]?.toString().toLowerCase() ?? "";
      final unloadPort = route["unloadPort"]?.toString().toLowerCase() ?? "";

      final cargo = job["cargo"] as Map<String, dynamic>? ?? {};
      final cargoType = cargo["type"]?.toString().toLowerCase() ?? "";
      final cargoDesc = cargo["description"]?.toString().toLowerCase() ?? "";

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
          driverName: _driverNameCache[job["driverId"]] ?? "Bilinmiyor",
          vehiclePlate: _vehiclePlateCache[job["vehicleId"]] ?? "Bilinmiyor",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📋 Header
            JobsPageHeader(selectedStatus: _selectedStatus),
            const SizedBox(height: 24),

            // 🔍 Search Bar
            JobsSearchBar(controller: _searchController),
            const SizedBox(height: 20),

            // 📊 Status Tabs
            JobsStatusTabs(
              selectedStatus: _selectedStatus,
              isDesktop: isDesktop,
              onStatusChanged: (status) {
                setState(() => _selectedStatus = status);
              },
            ),
            const SizedBox(height: 12),

            // 📦 Jobs List/Grid
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
                    return EmptyState(
                      icon: Icons.inbox_outlined,
                      title: "Henüz İş Yok",
                      subtitle: "Bu kategoride görüntülenecek iş bulunmuyor",
                    );
                  }

                  final allDocs = snapshot.data!.docs;
                  final filtered = _filterJobs(allDocs);

                  if (_searchQuery.isNotEmpty && filtered.isEmpty) {
                    return EmptyState(
                      icon: Icons.search_off_outlined,
                      title: "Sonuç Bulunamadı",
                      subtitle: "Aramanızla eşleşen iş bulunamadı",
                    );
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
        return JobCard(
          job: job,
          jobId: doc.id,
          driverName: _driverNameCache[job["driverId"]] ?? "Bilinmiyor",
          vehiclePlate: _vehiclePlateCache[job["vehicleId"]] ?? "Bilinmiyor",
          onTap: () => _openDetail(job, doc.id),
        );
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
        return JobCard(
          job: job,
          jobId: doc.id,
          driverName: _driverNameCache[job["driverId"]] ?? "Bilinmiyor",
          vehiclePlate: _vehiclePlateCache[job["vehicleId"]] ?? "Bilinmiyor",
          onTap: () => _openDetail(job, doc.id),
        );
      },
    );
  }
}
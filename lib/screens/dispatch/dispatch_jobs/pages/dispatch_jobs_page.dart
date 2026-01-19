// 📁 lib/pages/dispatch_jobs_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lojistik/services/firestore_service.dart';
import 'package:lojistik/services/auth_service.dart';
import 'package:go_router/go_router.dart';
import 'package:lojistik/screens/dispatch/dispatch_job_detail/pages/dispatch_job_detail_page.dart';
import '../widgets/jobs_page_header.dart';
import '../widgets/jobs_search_bar.dart';
import '../widgets/jobs_status_tabs.dart';
import '../widgets/job_card.dart';
import '../widgets/empty_state.dart';
import '../../../../models/job_model.dart';
import '../../../../models/user_model.dart';
import '../../../../models/vehicle_model.dart';

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
  final Map<String, AppUser> _driverCache = {};
  final Map<String, Vehicle> _vehicleCache = {};

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
      final companyId = await FirestoreService.getCompanyId();
      if (companyId == null) return;

      final drivers = await FirebaseFirestore.instance
          .collection('users')
          .where('companyId', isEqualTo: companyId)
          .where('role', isEqualTo: 'driver')
          .get();

      final vehicles = await FirebaseFirestore.instance
          .collection('vehicles')
          .where('companyId', isEqualTo: companyId)
          .get();

      setState(() {
        for (var doc in drivers.docs) {
          _driverCache[doc.id] = AppUser.fromFirestore(doc);
        }
        for (var doc in vehicles.docs) {
          _vehicleCache[doc.id] = Vehicle.fromFirestore(doc);
        }
        _loading = false;
      });
    } catch (e) {
      debugPrint('Cache load error: $e');
      setState(() => _loading = false);
    }
  }

  Stream<List<Job>> _jobsStream() {
    return FirestoreService.getJobsStream(
      status: _selectedStatus,
    );
  }

  List<Job> _filterJobs(List<Job> jobs) {
    if (_searchQuery.isEmpty) return jobs;

    return jobs.where((job) {
      final driverName = _driverCache[job.driverId]?.name.toLowerCase() ?? "";
      final vehiclePlate = _vehicleCache[job.vehicleId]?.plate.toLowerCase() ?? "";
      final loadPort = job.loadPort.toLowerCase();
      final unloadPort = job.unloadPort.toLowerCase();
      final cargoType = job.cargoType.toLowerCase();
      final cargoDesc = job.cargoDescription.toLowerCase();
      final refNo = job.referenceNo.toLowerCase();

      return driverName.contains(_searchQuery) ||
          vehiclePlate.contains(_searchQuery) ||
          loadPort.contains(_searchQuery) ||
          unloadPort.contains(_searchQuery) ||
          cargoType.contains(_searchQuery) ||
          cargoDesc.contains(_searchQuery) ||
          refNo.contains(_searchQuery);
    }).toList();
  }

  void _openDetail(Job job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DispatchJobDetailPage(
          jobId: job.id,
          job: job,
          driverName: _driverCache[job.driverId]?.name ?? "Bilinmiyor",
          vehiclePlate: _vehicleCache[job.vehicleId]?.plate ?? "Bilinmiyor",
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
              child: StreamBuilder<List<Job>>(
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

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return EmptyState(
                      icon: Icons.inbox_outlined,
                      title: "Henüz İş Yok",
                      subtitle: "Bu kategoride görüntülenecek iş bulunmuyor",
                    );
                  }

                  final allJobs = snapshot.data!;
                  final filtered = _filterJobs(allJobs);

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

  Widget _buildDesktopGrid(List<Job> jobs) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        return JobCard(
          job: job,
          jobId: job.id,
          driverName: _driverCache[job.driverId]?.name ?? "Bilinmiyor",
          vehiclePlate: _vehicleCache[job.vehicleId]?.plate ?? "Bilinmiyor",
          onTap: () => _openDetail(job),
        );
      },
    );
  }

  Widget _buildMobileList(List<Job> jobs) {
    return ListView.separated(
      itemCount: jobs.length,
      padding: const EdgeInsets.only(bottom: 32),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final job = jobs[index];
        return JobCard(
          job: job,
          jobId: job.id,
          driverName: _driverCache[job.driverId]?.name ?? "Bilinmiyor",
          vehiclePlate: _vehicleCache[job.vehicleId]?.plate ?? "Bilinmiyor",
          onTap: () => _openDetail(job),
        );
      },
    );
  }
}
import 'package:flutter/material.dart';

import '../widgets/completed_jobs_summary.dart';
import '../../../../services/firestore_service.dart';
import '../../../../utils/report_exporter.dart';
import '../widgets/completed_jobs_search.dart';
import '../widgets/date_filter_button.dart';
import '../widgets/date_range_picker_dialog.dart' as custom;
import '../widgets/completed_job_list_item.dart';
import '../widgets/completed_jobs_empty_state.dart';
import '../widgets/pagination_controls.dart';
import '../../../../models/job_model.dart';

class CompletedJobsPage extends StatefulWidget {
  final String uid;

  const CompletedJobsPage({super.key, required this.uid});

  @override
  State<CompletedJobsPage> createState() => _CompletedJobsPageState();
}

class _CompletedJobsPageState extends State<CompletedJobsPage> {
  // ======================================================
  // UI TOKENS
  // ======================================================
  static const Color primary = Color(0xFF1E3A5F);
  static const Color bg = Color(0xFFF8FAFC);

  // ======================================================
  // SEARCH & PAGINATION
  // ======================================================
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  int _currentPage = 1;
  final int _itemsPerPage = 10;

  // ======================================================
  // DATE FILTER
  // ======================================================
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
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

  // ======================================================
  // FIRESTORE
  // ======================================================
  Stream<List<Job>> _getCompletedJobs() {
    return FirestoreService.getJobsStream(status: 'completed');
  }

  // ======================================================
  // HELPERS
  // ======================================================
  DateTime? _jobCompletedAt(Job job) {
    return job.timestamps.completedAt ?? job.timestamps.reviewedAt;
  }

  DateTime? _jobCreatedAt(Job job) {
    return job.timestamps.createdAt;
  }

  // ======================================================
  // FILTER LOGIC
  // ======================================================
  bool _applyFilters(Job job) {
    if (_searchQuery.isNotEmpty) {
      final load = job.loadPort.toLowerCase();
      final unload = job.unloadPort.toLowerCase();
      if (!load.contains(_searchQuery) && !unload.contains(_searchQuery)) {
        return false;
      }
    }

    if (_dateRange != null) {
      final createdAt = _jobCreatedAt(job);
      if (createdAt == null) return false;

      final start = DateTime(_dateRange!.start.year, _dateRange!.start.month,
          _dateRange!.start.day);
      final end = DateTime(_dateRange!.end.year, _dateRange!.end.month,
          _dateRange!.end.day, 23, 59, 59);

      if (createdAt.isBefore(start) || createdAt.isAfter(end)) {
        return false;
      }
    }

    return true;
  }

  // ======================================================
  // FILTERING (Separated)
  // ======================================================
  List<Job> _getFilteredJobs(List<Job> jobs) {
    return jobs.where(_applyFilters).toList();
  }

  List<Job> _applySearchAndPagination(
      List<Job> filteredJobs) {
    
    // Pagination
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = start + _itemsPerPage;
    if (start >= filteredJobs.length) return [];

    return filteredJobs.sublist(
      start,
      end > filteredJobs.length ? filteredJobs.length : end,
    );
  }

  int _totalPages(int total) => (total / _itemsPerPage).ceil();

  // ======================================================
  // RANGE PICKER (BOTTOMSHEET)
  // ======================================================
  Future<void> _openDatePicker() async {
    final result = await custom.DateRangePickerDialog.show(context, _dateRange);
    if (result != null) {
      setState(() {
        _dateRange = result;
        _currentPage = 1;
      });
    }
  }

  void _clearDateFilter() {
    setState(() => _dateRange = null);
  }

  // ======================================================
  // UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: StreamBuilder<List<Job>>(
        stream: _getCompletedJobs(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(primary),
              ),
            );
          }

          final allJobs = snapshot.data!;

          allJobs.sort((a, b) {
            final da = _jobCompletedAt(a) ?? _jobCreatedAt(a) ?? DateTime(1970);
            final db = _jobCompletedAt(b) ?? _jobCreatedAt(b) ?? DateTime(1970);
            return db.compareTo(da);
          });

          final filteredJobs = _getFilteredJobs(allJobs);
          final visibleJobs = _searchQuery.isNotEmpty || _dateRange != null 
              ? filteredJobs 
              : _applySearchAndPagination(filteredJobs);

          return Column(
            children: [
              CompletedJobsSummary(
                totalJobs: filteredJobs.length,
                onExportPdf: () => ReportExporter.exportDriverJobsToPdf(
                  context: context,
                  jobs: filteredJobs,
                ),
                onExportExcel: () => ReportExporter.exportDriverJobsToExcel(
                  context: context,
                  jobs: filteredJobs,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    CompletedJobsSearch(controller: _searchController),
                    const SizedBox(height: 12),
                    DateFilterButton(
                      dateRange: _dateRange,
                      onPressed: _openDatePicker,
                      onClear: _clearDateFilter,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: visibleJobs.isEmpty
                    ? CompletedJobsEmptyState(
                        isFiltered: _searchQuery.isNotEmpty || _dateRange != null,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: visibleJobs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final job = visibleJobs[i];
                          return CompletedJobListItem(
                            job: job,
                            loadPort: job.loadPort,
                            unloadPort: job.unloadPort,
                          );
                        },
                      ),
              ),
              if (_searchQuery.isEmpty && _dateRange == null)
                PaginationControls(
                  currentPage: _currentPage,
                  totalPages: _totalPages(allJobs.length),
                  onPrevious: () => setState(() => _currentPage--),
                  onNext: () => setState(() => _currentPage++),
                ),
            ],
          );
        },
      ),
    );
  }
}

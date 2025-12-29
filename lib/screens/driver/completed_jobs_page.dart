import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';

import 'completed_job_detail_page.dart';

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
  static const Color border = Color(0xFFE2E8F0);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

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
  Stream<QuerySnapshot> _getCompletedJobs() {
    // Not: status: completed senin app’te var. Şemanda yok ama akışın için mantıklı.
    return FirebaseFirestore.instance
        .collection('jobs')
        .where('status', isEqualTo: 'completed')
        .where('driverId', isEqualTo: widget.uid)
        .where('softDeleted', isEqualTo: false)
    // timestamps.completedAt yoksa orderBy sıkıntı çıkarır.
    // Bu yüzden sıralamayı client-side yapıyoruz.
        .snapshots();
  }

  // ======================================================
  // HELPERS
  // ======================================================
  DateTime? _jobCompletedAt(Map<String, dynamic> job) {
    final ts = (job['timestamps'] as Map?)?.cast<String, dynamic>() ?? {};
    final completed = ts['completedAt'];
    final reviewed = ts['reviewedAt'];
    if (completed is Timestamp) return completed.toDate();
    if (reviewed is Timestamp) return reviewed.toDate();

    // fallback (eski yapı veya eksik)
    final legacy = job['completedAt'];
    if (legacy is Timestamp) return legacy.toDate();

    return null;
  }

  DateTime? _jobCreatedAt(Map<String, dynamic> job) {
    final ts = (job['timestamps'] as Map?)?.cast<String, dynamic>() ?? {};
    final created = ts['createdAt'];
    if (created is Timestamp) return created.toDate();

    // fallback (eski)
    final legacy = job['createdAt'];
    if (legacy is Timestamp) return legacy.toDate();

    return null;
  }

  String _loadPort(Map<String, dynamic> job) {
    final route = (job['route'] as Map?)?.cast<String, dynamic>() ?? {};
    return (route['loadPort'] ?? job['loadPort'] ?? '-').toString();
  }

  String _unloadPort(Map<String, dynamic> job) {
    final route = (job['route'] as Map?)?.cast<String, dynamic>() ?? {};
    return (route['unloadPort'] ?? job['unloadPort'] ?? '-').toString();
  }

  // ======================================================
  // FILTER LOGIC
  // ======================================================
  bool _applyFilters(Map<String, dynamic> job) {
    if (_searchQuery.isNotEmpty) {
      final load = _loadPort(job).toLowerCase();
      final unload = _unloadPort(job).toLowerCase();
      if (!load.contains(_searchQuery) && !unload.contains(_searchQuery)) {
        return false;
      }
    }

    if (_dateRange != null) {
      // tarih filtresi: createdAt üzerinden (eski davranışın aynısı)
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

  List<Map<String, dynamic>> _applySearchAndPagination(
      List<Map<String, dynamic>> jobs) {
    final filtered = jobs.where(_applyFilters).toList();

    if (_searchQuery.isNotEmpty || _dateRange != null) return filtered;

    final start = (_currentPage - 1) * _itemsPerPage;
    final end = start + _itemsPerPage;
    if (start >= filtered.length) return [];

    return filtered.sublist(
      start,
      end > filtered.length ? filtered.length : end,
    );
  }

  int _totalPages(int total) => (total / _itemsPerPage).ceil();

  // ======================================================
  // RANGE PICKER (BOTTOMSHEET)
  // ======================================================
  Future<void> _openDatePicker() async {
    List<DateTime?> tempValues = _dateRange == null
        ? []
        : [_dateRange!.start, _dateRange!.end];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Tarih Aralığı Seç",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    height: 300,
                    child: CalendarDatePicker2(
                      config: CalendarDatePicker2Config(
                        calendarType: CalendarDatePicker2Type.range,
                        selectedDayHighlightColor: primary,
                        selectedRangeHighlightColor: primary.withOpacity(0.25),
                        dayTextStyle: const TextStyle(color: textDark),
                        weekdayLabelTextStyle:
                        const TextStyle(fontWeight: FontWeight.w600),
                        controlsTextStyle:
                        const TextStyle(fontWeight: FontWeight.w600),
                        firstDayOfWeek: 1,
                      ),
                      value: tempValues,
                      onValueChanged: (values) {
                        setModalState(() => tempValues = values);
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("İptal"),
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                          ),
                          onPressed: () {
                            if (tempValues.length == 2 &&
                                tempValues[0] != null &&
                                tempValues[1] != null) {
                              setState(() {
                                _dateRange = DateTimeRange(
                                  start: tempValues[0]!,
                                  end: tempValues[1]!,
                                );
                                _currentPage = 1;
                              });
                            }
                            Navigator.pop(ctx);
                          },
                          child: const Text(
                            "Uygula",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _getCompletedJobs(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(primary),
              ),
            );
          }

          // docId lazım (detay sayfasında işine yarar)
          final allJobs = snapshot.data!.docs.map((doc) {
            final m = (doc.data() as Map<String, dynamic>?) ?? {};
            return {
              ...m,
              'id': doc.id,
            };
          }).toList();

          // client-side sort (timestamps.completedAt > timestamps.reviewedAt > createdAt)
          allJobs.sort((a, b) {
            final da = _jobCompletedAt(a) ?? _jobCreatedAt(a) ?? DateTime(1970);
            final db = _jobCompletedAt(b) ?? _jobCreatedAt(b) ?? DateTime(1970);
            return db.compareTo(da);
          });

          final visibleJobs = _applySearchAndPagination(allJobs);

          return Column(
            children: [
              // SUMMARY
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Tamamlanan İşler Özeti",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _summaryRow("Toplam İş", allJobs.length.toString()),
                  ],
                ),
              ),

              // SEARCH & FILTER
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: "Yükleme veya varış limanı ara",
                          prefixIcon: Icon(Icons.search, color: textMuted),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _openDatePicker,
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            _dateRange == null
                                ? "Tarih Filtrele"
                                : "${DateFormat('dd MMM yyyy', 'tr_TR').format(_dateRange!.start)} - "
                                "${DateFormat('dd MMM yyyy', 'tr_TR').format(_dateRange!.end)}",
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primary,
                            side: const BorderSide(color: primary),
                          ),
                        ),
                        if (_dateRange != null)
                          IconButton(
                            onPressed: _clearDateFilter,
                            icon: const Icon(Icons.close),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // LIST
              Expanded(
                child: visibleJobs.isEmpty
                    ? _buildListEmptyState(
                  isFiltered: _searchQuery.isNotEmpty || _dateRange != null,
                )
                    : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: visibleJobs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final job = visibleJobs[i];

                    final title = job['referenceNo'] ?? '-';
                    final subtitle =
                        "${_loadPort(job)} → ${_unloadPort(job)}";

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.check_circle_outline,
                          color: primary,
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(subtitle),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CompletedJobDetailsPage(
                                job: job, // job + id
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

              if (_searchQuery.isEmpty && _dateRange == null)
                _buildPagination(allJobs.length),
            ],
          );
        },
      ),
    );
  }

  Widget _buildListEmptyState({required bool isFiltered}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFiltered ? Icons.search_off_outlined : Icons.inbox_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            isFiltered ? "Sonuç bulunamadı" : "Tamamlanan iş yok",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: textMuted),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(int totalItems) {
    final totalPages = _totalPages(totalItems);
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Sayfa $_currentPage / $totalPages"),
          Row(
            children: [
              IconButton(
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

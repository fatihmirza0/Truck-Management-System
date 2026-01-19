import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:lojistik/services/firestore_service.dart';
import 'package:lojistik/utils/report_exporter.dart';
import '../../../dispatch/dispatch_job_detail/pages/dispatch_job_detail_page.dart';
import '../widgets/completed_jobs_header.dart';
import '../widgets/completed_jobs_filters.dart';
import '../widgets/completed_jobs_list_view.dart';
import '../../../../models/job_model.dart';
import '../../../../models/user_model.dart';
import '../../../../models/vehicle_model.dart';

class CompletedJobsPage extends StatefulWidget {
  const CompletedJobsPage({super.key});

  @override
  State<CompletedJobsPage> createState() => _CompletedJobsPageState();
}

class _CompletedJobsPageState extends State<CompletedJobsPage> {
  // --------------------------------------------------
  // UI TOKENS
  // --------------------------------------------------
  static const Color accent = Color(0xFF1E3A5F);
  static const Color bg = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  // --------------------------------------------------
  // STATE
  // --------------------------------------------------
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<DateTime?> _rangeDates = [];

  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedDriverId;

  final Map<String, AppUser> _driverCache = {};
  final Map<String, Vehicle> _vehicleCache = {};

  bool exportingPdf = false;
  bool exportingExcel = false;

  // --------------------------------------------------
  // INIT
  // --------------------------------------------------
  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  Future<void> _loadCache() async {
    _driverCache.clear();
    _vehicleCache.clear();

    try {
      final cid = await FirestoreService.getCompanyId();
      if (cid == null) return;

      final drivers = await FirestoreService.fetchAllUsers();
      final vehicles = await FirestoreService.fetchAllVehicles();

      setState(() {
        for (var u in drivers) {
          if (u.role == "driver") {
            _driverCache[u.uid] = u;
          }
        }
        for (var v in vehicles) {
          _vehicleCache[v.id] = v;
        }
      });
    } catch (e) {
      debugPrint("Cache load error: $e");
    }

    if (mounted) setState(() {});
  }

  // --------------------------------------------------
  // HELPERS
  // --------------------------------------------------
  String userName(String? uid) =>
      uid == null ? "-" : (_driverCache[uid]?.name ?? "-");

  String vehiclePlate(String? id) =>
      id == null ? "-" : (_vehicleCache[id]?.plate ?? "-");

  DateTime? completedAtFromJob(Job job) {
    return job.timestamps.completedAt;
  }

  String formatDateShort(DateTime d) {
    return "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";
  }


  // --------------------------------------------------
  // FIRESTORE
  // --------------------------------------------------
  Stream<List<Job>> _stream() {
    return FirestoreService.getJobsStream(status: "completed");
  }

  // --------------------------------------------------
  // FILTER
  // --------------------------------------------------
  List<Job> _applyFilters(List<Job> jobs) {
    final DateTime? start = _startDate == null
        ? null
        : DateTime(_startDate!.year, _startDate!.month, _startDate!.day);

    final DateTime? end = _endDate == null
        ? null
        : DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);

    return jobs.where((job) {
      final completedAt = completedAtFromJob(job);
      if (completedAt == null) return false;

      if (start != null && completedAt.isBefore(start)) return false;
      if (end != null && completedAt.isAfter(end)) return false;

      if (_selectedDriverId != null && job.driverId != _selectedDriverId) {
        return false;
      }

      return true;
    }).toList();
  }

  // --------------------------------------------------
  // DATE PICKER
  // --------------------------------------------------
  Future<void> _pickDateRange() async {
    final result = await showDialog<List<DateTime?>>(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Center(
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.date_range, color: accent),
                      const SizedBox(width: 8),
                      const Text(
                        "Tarih Aralığı Seç",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CalendarDatePicker2(
                    config: CalendarDatePicker2Config(
                      calendarType: CalendarDatePicker2Type.range,
                      selectedDayHighlightColor: accent,
                      weekdayLabelTextStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textMuted,
                      ),
                      controlsTextStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      dayTextStyle: const TextStyle(
                        fontSize: 13,
                        color: textDark,
                      ),
                      selectedDayTextStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      firstDate: DateTime(2022),
                      lastDate: DateTime.now(),
                      centerAlignModePicker: true,
                    ),
                    value: _rangeDates,
                    onValueChanged: (dates) {
                      _rangeDates = dates;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          _rangeDates = [];
                          Navigator.pop(context);
                          _clearDate();
                        },
                        child: const Text("Temizle", style: TextStyle(color: Colors.white)),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          if (_rangeDates.isNotEmpty) {
                            setState(() {
                              _startDate = _rangeDates.first;
                              _endDate =
                                  _rangeDates.length > 1 ? _rangeDates.last : _rangeDates.first;
                            });
                          }
                          Navigator.pop(context);
                        },
                        child: const Text("Uygula", style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result != null) {
      _rangeDates = result;
    }
  }

  void _clearDate() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  // --------------------------------------------------
  // DRIVER SELECTOR
  // --------------------------------------------------
  List<AppUser> _drivers() {
    final list = _driverCache.values.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> _openDriverSelector() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final ctrl = TextEditingController();
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (context, scrollCtrl) {
            return Container(
              decoration: const BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.person_search,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Şoför Seç",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: "Kapat",
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: ctrl,
                        decoration: const InputDecoration(
                          hintText: "İsim ile ara...",
                          prefixIcon: Icon(Icons.search, color: textMuted),
                          border: InputBorder.none,
                        ),
                        onChanged: (_) => (context as Element).markNeedsBuild(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final q = ctrl.text.trim().toLowerCase();
                        final list = _drivers().where((u) {
                          if (q.isEmpty) return true;
                          return u.name.toLowerCase().contains(q);
                        }).toList();

                        if (list.isEmpty) {
                          return const Center(
                            child: Text(
                              "Sonuç bulunamadı",
                              style: TextStyle(color: textMuted),
                            ),
                          );
                        }

                        return ListView.separated(
                          controller: scrollCtrl,
                          itemCount: list.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemBuilder: (_, i) {
                            final u = list[i];
                            final id = u.uid;
                            final name = u.name;
                            final selected = _selectedDriverId == id;

                            return Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => Navigator.pop(context, id),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected ? accent : border,
                                      width: selected ? 1.3 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: accent.withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.person_outline,
                                          color: accent,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w600,
                                            color: textDark,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (selected)
                                        const Icon(Icons.check_circle,
                                            color: accent, size: 20)
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDriverId = picked);
    }
  }

  void _clearDriver() {
    setState(() => _selectedDriverId = null);
  }

  // --------------------------------------------------
  // EXPORT
  // --------------------------------------------------
  Future<void> _runPdfExport() async {
    if (exportingPdf) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => exportingPdf = true);
    try {
      final jobs = await _stream().first;
      final filtered = _applyFilters(jobs);

      if (filtered.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text("Export edilecek kayıt yok.")));
        return;
      }

      final driversList = _driverCache.values.toList();
      if (!context.mounted) return;
      await ReportExporter.exportToPdf(
        context: context, 
        jobs: filtered, 
        users: driversList, 
        title: "Tamamlanan İş Raporu"
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("PDF export hatası: $e")));
    } finally {
      if (mounted) setState(() => exportingPdf = false);
    }
  }

  Future<void> _runExcelExport() async {
    if (exportingExcel) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => exportingExcel = true);
    try {
      final jobs = await _stream().first;
      final filtered = _applyFilters(jobs);

      if (filtered.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text("Export edilecek kayıt yok.")));
        return;
      }

      final driversList = _driverCache.values.toList();
      if (!context.mounted) return;
      await ReportExporter.exportToExcel(
        context: context, 
        jobs: filtered, 
        users: driversList
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Excel export hatası: $e")));
    } finally {
      if (mounted) setState(() => exportingExcel = false);
    }
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            final horizontalPadding = isWide ? 40.0 : 20.0;

            return Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CompletedJobsHeader(accentColor: accent),
                  const SizedBox(height: 12),
                  CompletedJobsFilters(
                    startDate: _startDate,
                    endDate: _endDate,
                    selectedDriverName:
                        _selectedDriverId == null ? null : userName(_selectedDriverId),
                    exportingPdf: exportingPdf,
                    exportingExcel: exportingExcel,
                    onPickDateRange: _pickDateRange,
                    onClearDate: _clearDate,
                    onOpenDriverSelector: _openDriverSelector,
                    onClearDriver: _clearDriver,
                    onRunPdfExport: _runPdfExport,
                    onRunExcelExport: _runExcelExport,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: CompletedJobsListView(
                      stream: _stream(),
                      applyFilters: _applyFilters,
                      userName: userName,
                      formatDateShort: formatDateShort,
                      onJobTap: (job, id) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DispatchJobDetailPage(
                              jobId: job.id,
                              job: job,
                              driverName: userName(job.driverId),
                              vehiclePlate: vehiclePlate(job.vehicleId),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

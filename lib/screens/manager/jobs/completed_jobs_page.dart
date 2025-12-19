import 'dart:io';

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import 'job_detail_panel.dart';

class CompletedJobsPage extends StatefulWidget {
  const CompletedJobsPage({super.key});

  @override
  State<CompletedJobsPage> createState() => _CompletedJobsPageState();
}

class _CompletedJobsPageState extends State<CompletedJobsPage> {
  // --------------------------------------------------
  // UI TOKENS (JobsPage ile aynı dil)
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

  Map<String, Map<String, dynamic>> userCache = {};
  Map<String, Map<String, dynamic>> vehicleCache = {};

  Map<String, dynamic>? _selectedJob;
  String? _selectedJobId;

  bool exportingPdf = false;
  bool exportingExcel = false;

  bool get isDesktop => MediaQuery.of(context).size.width > 900;

  // --------------------------------------------------
  // INIT
  // --------------------------------------------------
  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  Future<void> _loadCache() async {
    userCache.clear();
    vehicleCache.clear();

    final users = await FirebaseFirestore.instance
        .collection("users")
        .where("softDeleted", isEqualTo: false)
        .get();

    final vehicles = await FirebaseFirestore.instance
        .collection("vehicles")
        .where("isActive", isEqualTo: true)
        .get();

    for (var u in users.docs) {
      userCache[u.id] = u.data();
    }
    for (var v in vehicles.docs) {
      vehicleCache[v.id] = v.data();
    }

    if (mounted) setState(() {});
  }

  // --------------------------------------------------
  // HELPERS
  // --------------------------------------------------
  String userName(String? uid) =>
      uid == null ? "-" : (userCache[uid]?["name"] ?? "-");

  String vehiclePlate(String? id) =>
      id == null ? "-" : (vehicleCache[id]?["plate"] ?? "-");

  DateTime? completedAtFromJob(Map<String, dynamic> job) {
    return (job["timestamps"]?["completedAt"] as Timestamp?)?.toDate();
  }

  String formatDateShort(DateTime d) {
    return "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";
  }

  String formatTimestamp(Timestamp t) => formatDateShort(t.toDate());

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // --------------------------------------------------
  // FIRESTORE
  // --------------------------------------------------
  Stream<QuerySnapshot> _stream() {
    return FirebaseFirestore.instance
        .collection("jobs")
        .where("softDeleted", isEqualTo: false)
        .where("status", isEqualTo: "completed")
        .orderBy("timestamps.completedAt", descending: true)
        .snapshots();
  }

  // --------------------------------------------------
  // FILTER
  // --------------------------------------------------
  List<QueryDocumentSnapshot> _applyFilters(List<QueryDocumentSnapshot> docs) {
    final DateTime? start = _startDate == null
        ? null
        : DateTime(_startDate!.year, _startDate!.month, _startDate!.day);

    final DateTime? end = _endDate == null
        ? null
        : DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);

    return docs.where((doc) {
      final job = doc.data() as Map<String, dynamic>;
      final completedAt = completedAtFromJob(job);
      if (completedAt == null) return false;

      if (start != null && completedAt.isBefore(start)) return false;
      if (end != null && completedAt.isAfter(end)) return false;

      if (_selectedDriverId != null && job["driverId"] != _selectedDriverId) {
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
                  // HEADER
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

                  // CALENDAR
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

                  // ACTIONS
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          _rangeDates = [];
                          Navigator.pop(context);
                          _clearDate();
                        },
                        child: const Text("Temizle",style: TextStyle(color: Color(0xFF1E3A5F)),),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF1E3A5F),
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
                        child: const Text("Uygula",style: TextStyle(color: Colors.white),),
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
  // DRIVER SELECTOR (50 şoför + için doğru UX)
  // --------------------------------------------------
  List<MapEntry<String, Map<String, dynamic>>> _drivers() {
    final list =
        userCache.entries.where((e) => e.value["role"] == "driver").toList();
    list.sort((a, b) => (a.value["name"] ?? "")
        .toString()
        .compareTo((b.value["name"] ?? "").toString()));
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
                      color: Colors.black.withOpacity(0.12),
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
                            color: Colors.black.withOpacity(0.03),
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
                        final list = _drivers().where((e) {
                          if (q.isEmpty) return true;
                          final name =
                              (e.value["name"] ?? "").toString().toLowerCase();
                          return name.contains(q);
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
                            final e = list[i];
                            final id = e.key;
                            final name = (e.value["name"] ?? "-").toString();
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
                                          color: accent.withOpacity(0.12),
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
  // DETAIL OPEN (tek tık fix)
  // --------------------------------------------------
  void _openDetail(Map<String, dynamic> job, String id) {
    setState(() {
      _selectedJob = job;
      _selectedJobId = id;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldKey.currentState?.openEndDrawer();
    });
  }

  // --------------------------------------------------
  // EXPORT BUTTON ACTIONS (UI düzenli + boş veri korumalı)
  // --------------------------------------------------
  Future<void> _runPdfExport() async {
    if (exportingPdf) return;

    setState(() => exportingPdf = true);
    try {
      final snap = await _stream().first;
      final filtered = _applyFilters(snap.docs);

      if (filtered.isEmpty) {
        _toast("Export edilecek kayıt yok.");
        return;
      }

      await _exportPdf(filtered);
    } catch (e) {
      _toast("PDF export hatası: $e");
    } finally {
      if (mounted) setState(() => exportingPdf = false);
    }
  }

  Future<void> _runExcelExport() async {
    if (exportingExcel) return;

    setState(() => exportingExcel = true);
    try {
      final snap = await _stream().first;
      final filtered = _applyFilters(snap.docs);

      if (filtered.isEmpty) {
        _toast("Export edilecek kayıt yok.");
        return;
      }

      await _exportExcel(filtered);
    } catch (e) {
      _toast("Excel export hatası: $e");
    } finally {
      if (mounted) setState(() => exportingExcel = false);
    }
  }

  // --------------------------------------------------
  // EXPORT - EXCEL
  // --------------------------------------------------
  Future<void> _exportExcel(List<QueryDocumentSnapshot> jobs) async {
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = "Completed Jobs";

    final headers = [
      "Referans",
      "Şoför",
      "Plaka",
      "Yük",
      "Kg",
      "Tamamlanma Tarihi"
    ];

    for (int i = 0; i < headers.length; i++) {
      sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
    }

    int row = 2;
    for (var doc in jobs) {
      final j = doc.data() as Map<String, dynamic>;
      final cargo = j["cargo"] as Map<String, dynamic>?;
      final completedAt = j["timestamps"]?["completedAt"] as Timestamp?;

      sheet
          .getRangeByIndex(row, 1)
          .setText((j["referenceNo"] ?? "-").toString());
      sheet.getRangeByIndex(row, 2).setText(userName(j["driverId"]));
      sheet.getRangeByIndex(row, 3).setText(vehiclePlate(j["vehicleId"]));
      sheet.getRangeByIndex(row, 4).setText((cargo?["type"] ?? "-").toString());
      sheet
          .getRangeByIndex(row, 5)
          .setNumber(((cargo?["weightKg"] ?? 0) as num).toDouble());
      sheet.getRangeByIndex(row, 6).setText(
            completedAt == null ? "-" : formatTimestamp(completedAt),
          );
      row++;
    }

    final bytes = workbook.saveAsStream();
    workbook.dispose();

    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/completed_jobs.xlsx");
    await file.writeAsBytes(bytes, flush: true);

    await OpenFilex.open(file.path);
  }

  // --------------------------------------------------
  // EXPORT - PDF
  // --------------------------------------------------
  Future<void> _exportPdf(List<QueryDocumentSnapshot> jobs) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Text(
            "Tamamlanan İşler",
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Table.fromTextArray(
            headers: ["Ref", "Şoför", "Plaka", "Yük", "Kg", "Tarih"],
            data: jobs.map((doc) {
              final j = doc.data() as Map<String, dynamic>;
              final cargo = j["cargo"] as Map<String, dynamic>?;
              final completedAt = j["timestamps"]?["completedAt"] as Timestamp?;

              return [
                (j["referenceNo"] ?? "-").toString(),
                userName(j["driverId"]),
                vehiclePlate(j["vehicleId"]),
                (cargo?["type"] ?? "-").toString(),
                (cargo?["weightKg"] ?? 0).toString(),
                completedAt == null ? "-" : formatTimestamp(completedAt),
              ];
            }).toList(),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/completed_jobs.pdf");
    await file.writeAsBytes(await pdf.save());

    await OpenFilex.open(file.path);
  }

  // --------------------------------------------------
  // UI PIECES
  // --------------------------------------------------
  Widget _pill({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    VoidCallback? onClear,
    bool loading = false,
    bool primary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: primary ? accent : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: primary ? accent : border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading) ...[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
              ] else ...[
                Icon(
                  icon,
                  size: 18,
                  color: primary ? Colors.white : textMuted,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: primary ? Colors.white : textDark,
                ),
              ),
              if (onClear != null && !loading) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: onClear,
                  borderRadius: BorderRadius.circular(8),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: primary ? Colors.white.withOpacity(0.9) : textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
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
            "Kayıt Bulunamadı",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Seçtiğiniz filtrelerle eşleşen tamamlanan iş yok",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bg,
      endDrawer: _selectedJob == null
          ? null
          : JobDetailPanel(
              job: _selectedJob!,
              jobId: _selectedJobId!,
              userName: userName,
              vehiclePlate: vehiclePlate,
              onApprove: () {},
              onReject: (_) {},
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER (JobsPage stili)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.done_all_outlined,
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
                          "Tamamlanan İşler",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: accent,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Filtreleyin, dışa aktarın ve detayları inceleyin",
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

              const SizedBox(height: 20),

              // FILTER BAR (kurumsal + temiz)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // SOL TARAF – FİLTRELER
                    Expanded(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _pill(
                            icon: Icons.date_range,
                            text: _startDate == null
                                ? "Tarih"
                                : "${formatDateShort(_startDate!)} → ${formatDateShort(_endDate ?? _startDate!)}",
                            onTap: _pickDateRange,
                            onClear: _startDate == null ? null : _clearDate,
                          ),
                          _pill(
                            icon: Icons.person_outline,
                            text: _selectedDriverId == null
                                ? "Şoför"
                                : userName(_selectedDriverId),
                            onTap: _openDriverSelector,
                            onClear: _selectedDriverId == null ? null : _clearDriver,
                          ),
                        ],
                      ),
                    ),

                    // SAĞ TARAF – EXPORT BUTONLARI
                    Wrap(
                      spacing: 12,
                      children: [
                        _pill(
                          icon: Icons.picture_as_pdf,
                          text: exportingPdf ? "PDF hazırlanıyor..." : "PDF",
                          onTap: _runPdfExport,
                          loading: exportingPdf,
                          primary: true,
                        ),
                        _pill(
                          icon: Icons.table_chart,
                          text: exportingExcel ? "Excel hazırlanıyor..." : "Excel",
                          onTap: _runExcelExport,
                          loading: exportingExcel,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // LIST
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _stream(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(accent),
                        ),
                      );
                    }

                    final filtered = _applyFilters(snap.data!.docs);

                    if (filtered.isEmpty) return _emptyState();

                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 32),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final d = filtered[i];
                        final j = d.data() as Map<String, dynamic>;
                        final cargo = j["cargo"] as Map<String, dynamic>?;
                        final route = j["route"] as Map<String, dynamic>?;
                        final completedAt = completedAtFromJob(j);

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border),
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
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _openDetail(j, d.id),
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
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.tag,
                                            size: 20,
                                            color: accent,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            (j["referenceNo"] ?? "-")
                                                .toString(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: textDark,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: accent.withOpacity(0.10),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            completedAt == null
                                                ? "-"
                                                : formatDateShort(completedAt),
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: accent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _infoRow(
                                      Icons.person_outline,
                                      "Şoför",
                                      userName(j["driverId"]),
                                    ),
                                    const SizedBox(height: 8),
                                    _infoRow(
                                      Icons.car_rental_outlined,
                                      "Plaka",
                                      vehiclePlate(j["vehicleId"]),
                                    ),
                                    const SizedBox(height: 8),
                                    _infoRow(
                                      Icons.inventory_2_outlined,
                                      "Yük",
                                      "${cargo?["type"] ?? "-"} • ${(cargo?["weightKg"] ?? 0)} kg",
                                    ),
                                    const SizedBox(height: 8),
                                    _infoRow(
                                      Icons.route_outlined,
                                      "Güzergah",
                                      "${route?["loadPort"] ?? "-"} → ${route?["unloadPort"] ?? "-"}",
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: const [
                                        Spacer(),
                                        Icon(Icons.chevron_right,
                                            color: textMuted),
                                      ],
                                    )
                                  ],
                                ),
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
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: textMuted),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: const TextStyle(
            fontSize: 13,
            color: textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

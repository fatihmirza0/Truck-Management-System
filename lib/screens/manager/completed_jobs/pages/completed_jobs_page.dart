import 'dart:io';

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import 'package:lojistik/services/firestore_service.dart';
import '../../../dispatch/dispatch_job_detail/pages/dispatch_job_detail_page.dart';
import '../widgets/completed_jobs_header.dart';
import '../widgets/completed_jobs_filters.dart';
import '../widgets/completed_jobs_list_view.dart';

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
  String? _companyId;

  Map<String, Map<String, dynamic>> userCache = {};
  Map<String, Map<String, dynamic>> vehicleCache = {};

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
    userCache.clear();
    vehicleCache.clear();

    try {
      final cid = await FirestoreService.getCompanyId();
      if (mounted) {
        setState(() {
          _companyId = cid;
        });
      }

      if (cid == null) return;

      final users = await FirebaseFirestore.instance
          .collection("users")
          .where("companyId", isEqualTo: cid) // 🔥 SAAS
          .where("softDeleted", isEqualTo: false)
          .get();

      final vehicles = await FirebaseFirestore.instance
          .collection("vehicles")
          .where("companyId", isEqualTo: cid) // 🔥 SAAS
          .where("isActive", isEqualTo: true)
          .get();

      for (var u in users.docs) {
        userCache[u.id] = u.data();
      }
      for (var v in vehicles.docs) {
        vehicleCache[v.id] = v.data();
      }
    } catch (e) {
      debugPrint("Cache load error: $e");
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
    if (_companyId == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection("jobs")
        .where("companyId", isEqualTo: _companyId) // 🔥 SAAS
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

    // Dinamik dosya ismi
    String fileName = "tamamlanan_isler";
    if (_startDate != null) {
      fileName += "_${formatDateShort(_startDate!)}-${formatDateShort(_endDate ?? _startDate!)}";
    }

    final path = await FilePicker.platform.saveFile(
      dialogTitle: "Excel Raporunu Kaydet",
      fileName: "$fileName.xlsx",
      type: FileType.custom,
      allowedExtensions: ["xlsx"],
    );

    if (path == null) return; // Kullanıcı iptal etti

    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    await OpenFilex.open(file.path);
  }

  Future<void> _exportPdf(List<QueryDocumentSnapshot> jobs) async {
    try {
      final pdf = pw.Document();

      // Fontları yükle (Türkçe karakter desteği için)
      final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
      final fontBoldData = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
      final ttfBase = pw.Font.ttf(fontData);
      final ttfBold = pw.Font.ttf(fontBoldData);

      // Filtre bilgisini oluştur
      String filterInfo = "Tüm Kayıtlar";
      if (_startDate != null) {
        filterInfo =
            "Tarih: ${formatDateShort(_startDate!)} - ${formatDateShort(_endDate ?? _startDate!)}";
      }
      if (_selectedDriverId != null) {
        final name = userName(_selectedDriverId);
        if (_startDate != null) {
          filterInfo += "  |  Şoför: $name";
        } else {
          filterInfo = "Şoför: $name";
        }
      }

      pdf.addPage(
        pw.MultiPage(
          theme: pw.ThemeData.withFont(
            base: ttfBase,
            bold: ttfBold,
          ),
          pageFormat: const PdfPageFormat(
            21.0 * PdfPageFormat.cm,
            29.7 * PdfPageFormat.cm,
            marginAll: 2.0 * PdfPageFormat.cm,
          ),
          header: (context) => pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Tamamlanan İş Raporu",
                    style: pw.TextStyle(
                        fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.Text(formatDateShort(DateTime.now()),
                    style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
          ),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
            child: pw.Text(
              "Sayfa ${context.pageNumber} / ${context.pagesCount}",
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ),
          build: (context) => [
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8, bottom: 20),
              child: pw.Text(filterInfo,
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey700,
                  )),
            ),
            pw.Table.fromTextArray(
              headerStyle:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headers: ["Ref No", "Şoför", "Plaka", "Yük Tipi", "Kilo", "Tarih"],
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              data: jobs.map((doc) {
                final j = doc.data() as Map<String, dynamic>;
                final cargo = j["cargo"] as Map<String, dynamic>?;
                final completedAt = completedAtFromJob(j);

                return [
                  (j["referenceNo"] ?? "-").toString(),
                  userName(j["driverId"]),
                  vehiclePlate(j["vehicleId"]),
                  (cargo?["type"] ?? "-").toString(),
                  (cargo?["weightKg"] ?? 0).toString(),
                  completedAt == null ? "-" : formatDateShort(completedAt),
                ];
              }).toList(),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      
      // Dinamik dosya ismi
      String fileName = "tamamlanan_isler_raporu";
      if (_startDate != null) {
        fileName += "_${formatDateShort(_startDate!)}-${formatDateShort(_endDate ?? _startDate!)}";
      }

      final path = await FilePicker.platform.saveFile(
        dialogTitle: "PDF Raporunu Kaydet",
        fileName: "$fileName.pdf",
        type: FileType.custom,
        allowedExtensions: ["pdf"],
      );

      if (path == null) return; // Kullanıcı iptal etti

      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);
      await OpenFilex.open(file.path);
    } catch (e) {
      debugPrint("PDF Export Error: $e");
      _toast("PDF export hatası oluştu.");
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
                              jobId: id,
                              data: job,
                              driverName: userName(job["driverId"]),
                              vehiclePlate: vehiclePlate(job["vehicleId"]),
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

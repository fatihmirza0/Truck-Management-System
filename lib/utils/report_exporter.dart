// -----------------------------------------------------------------------------
// 📄 REPORT EXPORTER – LOGO + KPI + TÜRKÇE FONT + 12 AY GRAFİK + FİLTRELİ EXPORT
// -----------------------------------------------------------------------------

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_xlsio/xlsio.dart';

class ReportExporter {
  // ---------------------------------------------------------
  /// Font yükleme
  // ---------------------------------------------------------
  static Future<pw.Font> _fontRegular() async {
    final data = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    return pw.Font.ttf(data);
  }

  static Future<pw.Font> _fontBold() async {
    final data = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    return pw.Font.ttf(data);
  }

  // ---------------------------------------------------------
  /// PDF EXPORT
  // ---------------------------------------------------------
  static Future<File?> exportPdf({
    required int year,
    required int? month,
    required List<Map<String, dynamic>> drivers,
    required List<Map<String, dynamic>> dispatchers,
    required List<int> monthlyChart,
    required int today,
    required int weekly,
    required int monthly,
    required int prevYearJobs,
    required double jobChangePercent,
    required int totalDrivers,
    required int totalDispatch,
  }) async {
    final font = await _fontRegular();
    final bold = await _fontBold();

    Uint8List? logoBytes;
    try {
      logoBytes =
          (await rootBundle.load("assets/logo.png")).buffer.asUint8List();
    } catch (_) {}

    if (monthlyChart.length < 12) {
      monthlyChart = [
        ...monthlyChart,
        ...List.filled(12 - monthlyChart.length, 0),
      ];
    }

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: bold),
    );

    // Dönem metni oluştur
    String periodText = "$year";
    if (month != null) {
      const monthNames = [
        "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
        "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"
      ];
      periodText = "${monthNames[month - 1]} $year";
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          // HEADER
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (logoBytes != null)
                pw.Container(
                  height: 60,
                  child: pw.Image(pw.MemoryImage(logoBytes)),
                ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    "Lojistik Yönetim Raporu",
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    "Dönem: $periodText",
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 15),
          pw.Divider(),

          // KPI ÖZET
          pw.SizedBox(height: 12),
          _kpiTable(
            today,
            weekly,
            monthly,
            prevYearJobs,
            jobChangePercent,
            totalDrivers,
            totalDispatch,
          ),
          pw.SizedBox(height: 25),

          // AYLIK GRAFİK
          pw.Text(
            "Aylık İş Dağılımı",
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          _chart(monthlyChart),
          pw.SizedBox(height: 15),

          // ŞOFÖR PERFORMANCE
          pw.Text(
            "Şoför Performansı",
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          _driverTable(drivers),
          pw.SizedBox(height: 30),

          // DISPATCH PERFORMANCE
          pw.Text(
            "Dispatch Performansı",
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          _dispatchTable(dispatchers),
        ],
      ),
    );

    final path = await FilePicker.platform.saveFile(
      dialogTitle: "PDF Kaydet",
      fileName: "lojistik_rapor_$periodText.pdf",
      allowedExtensions: ["pdf"],
      type: FileType.custom,
    );

    if (path == null) return null;
    final f = File(path);
    await f.writeAsBytes(await pdf.save());
    return f;
  }

  // KPI TABLE
  static pw.Widget _kpiTable(
      int today,
      int weekly,
      int monthly,
      int prevYearJobs,
      double jobChangePercent,
      int totalDrivers,
      int totalDispatch,
      ) {
    final changeText = jobChangePercent >= 0
        ? "+${jobChangePercent.toStringAsFixed(1)}%"
        : "${jobChangePercent.toStringAsFixed(1)}%";

    return pw.Table.fromTextArray(
      headers: const ["Metrik", "Değer"],
      data: [
        ["Bugünkü İşler", today.toString()],
        ["Haftalık İşler", weekly.toString()],
        ["Aylık İşler", monthly.toString()],
        ["Geçen Yıl Aynı Dönem", prevYearJobs.toString()],
        ["Değişim Oranı", changeText],
        ["Toplam Şoför", totalDrivers.toString()],
        ["Toplam Dispatch", totalDispatch.toString()],
      ],
      border: pw.TableBorder.all(color: PdfColors.grey),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellAlignment: pw.Alignment.centerLeft,
      cellHeight: 22,
      headerDecoration: const pw.BoxDecoration(color: PdfColor(0.85, 0.9, 1)),
    );
  }

  // 12 AYLIK GRAFİK
  static pw.Widget _chart(List<int> list) {
    const months = [
      "Oca", "Şub", "Mar", "Nis", "May", "Haz",
      "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"
    ];

    final int maxVal = list.reduce((a, b) => a > b ? a : b);
    final double max = maxVal == 0 ? 1 : maxVal.toDouble();

    return pw.Container(
      height: 240,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8),
      child: pw.Column(
        children: [
          // ---- ÇUBUKLAR + DEĞERLER ----
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: List.generate(12, (i) {
                final double h = ((list[i] / max) * 150).clamp(3, 150);
                final v = list[i];

                return pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    // değer yazısı
                    pw.Text(
                      v.toString(),
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                    pw.SizedBox(height: 4),

                    // bar çizimi
                    pw.Container(
                      width: 20,
                      height: h,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                    ),
                    pw.SizedBox(height: 6),

                    // ay etiketi
                    pw.Text(
                      months[i],
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                );
              }),
            ),
          )
        ],
      ),
    );
  }

  // ŞOFÖR TABLOSU (GENİŞLETİLMİŞ)
  static pw.Widget _driverTable(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return pw.Text("Şoför verisi yok", style: pw.TextStyle(fontSize: 12));
    }

    return pw.Table.fromTextArray(
      headers: const [
        "Ad Soyad",
        "Plaka",
        "İş Sayısı",
        "Toplam KM",
        "Ort. KM/İş",
        "Ort. Süre (saat)"
      ],
      data: data.map((e) {
        return [
          e["name"] ?? "-",
          e["plate"] ?? "-",
          e["jobs"]?.toString() ?? "0",
          e["km"]?.toString() ?? "0",
          e["avgKm"]?.toString() ?? "0",
          e["avgHours"]?.toString() ?? "0",
        ];
      }).toList(),
      border: pw.TableBorder.all(color: PdfColors.grey),
      cellAlignment: pw.Alignment.centerLeft,
      cellHeight: 20,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColor(0.85, 0.9, 1)),
    );
  }

  // DISPATCH TABLOSU
  static pw.Widget _dispatchTable(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return pw.Text("Dispatch verisi yok", style: pw.TextStyle(fontSize: 12));
    }

    return pw.Table.fromTextArray(
      headers: const ["Ad Soyad", "İş Sayısı"],
      data: data.map((e) {
        return [
          e["name"] ?? "-",
          e["jobs"]?.toString() ?? "0",
        ];
      }).toList(),
      border: pw.TableBorder.all(color: PdfColors.grey),
      cellAlignment: pw.Alignment.centerLeft,
      cellHeight: 20,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColor(0.85, 0.9, 1)),
    );
  }

  // ---------------------------------------------------------
  /// EXCEL EXPORT
  // ---------------------------------------------------------
  static Future<File?> exportExcel({
    required int year,
    required int? month,
    required List<Map<String, dynamic>> drivers,
    required List<Map<String, dynamic>> dispatchers,
  }) async {
    final wb = Workbook();

    // Drivers sheet
    final s1 = wb.worksheets[0];
    s1.name = "Soforler";
    _writeDriverSheet(s1, drivers, year, month);

    // Dispatch sheet
    final s2 = wb.worksheets.addWithName("Dispatch");
    _writeDispatchSheet(s2, dispatchers, year, month);

    final bytes = wb.saveAsStream();
    wb.dispose();

    // Dönem metni oluştur
    String periodText = "$year";
    if (month != null) {
      const monthNames = [
        "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
        "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"
      ];
      periodText = "${monthNames[month - 1]} $year";
    }

    final path = await FilePicker.platform.saveFile(
      dialogTitle: "Excel Kaydet",
      fileName: "lojistik_rapor_$periodText.xlsx",
      type: FileType.custom,
      allowedExtensions: ["xlsx"],
    );

    if (path == null) return null;

    final f = File(path);
    await f.writeAsBytes(bytes);
    return f;
  }

  static void _writeDriverSheet(
      Worksheet sheet,
      List<Map<String, dynamic>> data,
      int year,
      int? month,
      ) {
    // Dönem başlığı
    String periodText = "$year";
    if (month != null) {
      const monthNames = [
        "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
        "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"
      ];
      periodText = "${monthNames[month - 1]} $year";
    }

    sheet.getRangeByIndex(1, 1).setText("ŞOFÖR PERFORMANS RAPORU - $periodText");
    sheet.getRangeByIndex(1, 1).cellStyle.bold = true;
    sheet.getRangeByIndex(1, 1).cellStyle.fontSize = 14;

    // Header (3. satırdan başla)
    const headers = [
      "Ad Soyad",
      "Plaka",
      "İş Sayısı",
      "Toplam KM",
      "Ort. KM/İş",
      "Ort. Süre (saat)"
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(3, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = "#D6EAF8";
    }

    // Data
    for (int r = 0; r < data.length; r++) {
      final row = data[r];
      sheet.getRangeByIndex(r + 4, 1).setText(row["name"]?.toString() ?? "-");
      sheet.getRangeByIndex(r + 4, 2).setText(row["plate"]?.toString() ?? "-");
      sheet.getRangeByIndex(r + 4, 3).setNumber(double.tryParse(row["jobs"]?.toString() ?? "0") ?? 0);
      sheet.getRangeByIndex(r + 4, 4).setText(row["km"]?.toString() ?? "0");
      sheet.getRangeByIndex(r + 4, 5).setText(row["avgKm"]?.toString() ?? "0");
      sheet.getRangeByIndex(r + 4, 6).setText(row["avgHours"]?.toString() ?? "0");
    }

    // Otomatik kolon genişliği
    for (int i = 1; i <= headers.length; i++) {
      sheet.autoFitColumn(i);
    }
  }

  static void _writeDispatchSheet(
      Worksheet sheet,
      List<Map<String, dynamic>> data,
      int year,
      int? month,
      ) {
    // Dönem başlığı
    String periodText = "$year";
    if (month != null) {
      const monthNames = [
        "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
        "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"
      ];
      periodText = "${monthNames[month - 1]} $year";
    }

    sheet.getRangeByIndex(1, 1).setText("DISPATCH PERFORMANS RAPORU - $periodText");
    sheet.getRangeByIndex(1, 1).cellStyle.bold = true;
    sheet.getRangeByIndex(1, 1).cellStyle.fontSize = 14;

    // Header
    const headers = ["Ad Soyad", "İş Sayısı"];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(3, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = "#D6EAF8";
    }

    // Data
    for (int r = 0; r < data.length; r++) {
      final row = data[r];
      sheet.getRangeByIndex(r + 4, 1).setText(row["name"]?.toString() ?? "-");
      sheet.getRangeByIndex(r + 4, 2).setNumber(double.tryParse(row["jobs"]?.toString() ?? "0") ?? 0);
    }

    // Otomatik kolon genişliği
    for (int i = 1; i <= headers.length; i++) {
      sheet.autoFitColumn(i);
    }
  }
}
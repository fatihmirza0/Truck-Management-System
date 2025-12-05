// -----------------------------------------------------------------------------
// 📄 REPORT EXPORTER – LOGO + KPI + TÜRKÇE FONT + 12 AY GRAFİK
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
    required List<Map<String, dynamic>> drivers,
    required List<Map<String, dynamic>> dispatchers,
    required List<int> monthlyChart,
    required int today,
    required int weekly,
    required int monthly,
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
              pw.Text(
                "Lojistik Yönetim Raporu",
                style: pw.TextStyle(
                    fontSize: 22, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 15),
          pw.Divider(),

          // KPI ÖZET
          pw.SizedBox(height: 12),
          _kpiTable(today, weekly, monthly, totalDrivers, totalDispatch),
          pw.SizedBox(height: 25),

          // AYLIK GRAFİK
          pw.Text("Aylık İş Dağılımı",
              style:
              pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          _chart(monthlyChart),
          pw.SizedBox(height: 15),

          // ŞOFÖR PERFORMANCE
          pw.Text("Şoför Performansı",
              style:
              pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _table(drivers),
          pw.SizedBox(height: 30),

          // DISPATCH PERFORMANCE
          pw.Text("Dispatch Performansı",
              style:
              pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _table(dispatchers),
        ],
      ),
    );

    final path = await FilePicker.platform.saveFile(
      dialogTitle: "PDF Kaydet",
      fileName: "lojistik_rapor.pdf",
      allowedExtensions: ["pdf"],
      type: FileType.custom,
    );

    if (path == null) return null;
    final f = File(path);
    await f.writeAsBytes(await pdf.save());
    return f;
  }

  // KPI TABLE
  static pw.Widget _kpiTable(int today, int weekly, int monthly,
      int totalDrivers, int totalDispatch) {
    return pw.Table.fromTextArray(
      headers: const ["Metrik", "Değer"],        // headerVisible yerine
      data: [
        ["Bugünkü İşler", today],
        ["Haftalık İşler", weekly],
        ["Aylık İşler", monthly],
        ["Toplam Şoför", totalDrivers],
        ["Toplam Dispatch", totalDispatch],
      ],
      border: pw.TableBorder.all(color: PdfColors.grey),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellAlignment: pw.Alignment.centerLeft,
      cellHeight: 22,
      headerDecoration: const pw.BoxDecoration(color: PdfColor(0.85, 0.9, 1)),
    );
  }


  // 12 AYLIK GRAFİK
// 12 AYLIK GRAFİK – değerler üstte görünüyor, boş aylar da gösteriliyor
  static pw.Widget _chart(List<int> list) {
    final months = ["Oca","Şub","Mar","Nis","May","Haz","Tem","Ağu","Eyl","Eki","Kas","Ara"];

    final int maxVal = list.reduce((a,b) => a>b?a:b);
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

                final double h = ((list[i] / max) * 150).clamp(3, 150); // sıfır olsa da ince bar
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
                    pw.Text(months[i],
                        style: const pw.TextStyle(fontSize: 9)),
                  ],
                );
              }),
            ),
          )
        ],
      ),
    );
  }

  // TABLO
  static pw.Widget _table(List<Map<String, dynamic>> data) {
    final columnsTr = {
      "name": "Ad Soyad",
      "plate": "Plaka",
      "jobs": "İş Sayısı",
      "km": "Toplam KM",
    };

    return pw.Table.fromTextArray(
      headers: data.first.keys.map((e) => columnsTr[e] ?? e).toList(),
      data: data.map((e) => e.values.toList()).toList(),
      border: pw.TableBorder.all(color: PdfColors.grey),
      cellAlignment: pw.Alignment.centerLeft,
      cellHeight: 20,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration:
      const pw.BoxDecoration(color: PdfColor(0.85, 0.9, 1)),
    );
  }

  // ---------------------------------------------------------
  /// EXCEL EXPORT
  // ---------------------------------------------------------
  static Future<File?> exportExcel({
    required List<Map<String, dynamic>> drivers,
    required List<Map<String, dynamic>> dispatchers,
  }) async {
    final wb = Workbook();

    // Drivers sheet
    final s1 = wb.worksheets[0];
    s1.name = "Soforler";
    _writeExcelSheet(s1, drivers);

    // Dispatch sheet
    final s2 = wb.worksheets.addWithName("Dispatch");
    _writeExcelSheet(s2, dispatchers);

    final bytes = wb.saveAsStream();
    wb.dispose();

    final path = await FilePicker.platform.saveFile(
      dialogTitle: "Excel Kaydet",
      fileName: "lojistik_rapor.xlsx",
      type: FileType.custom,
      allowedExtensions: ["xlsx"],
    );

    if (path == null) return null;

    final f = File(path);
    await f.writeAsBytes(bytes);
    return f;
  }

  static void _writeExcelSheet(Worksheet sheet, List<Map<String, dynamic>> data) {
    if (data.isEmpty) return;
    var headers = data.first.keys.toList();

    for (int i = 0; i < headers.length; i++) {
      sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
    }

    for (int r = 0; r < data.length; r++) {
      var row = data[r].values.toList();
      for (int c = 0; c < row.length; c++) {
        sheet.getRangeByIndex(r + 2, c + 1).setText(row[c].toString());
      }
    }
  }
}

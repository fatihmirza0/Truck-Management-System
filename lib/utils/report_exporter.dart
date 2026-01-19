// -----------------------------------------------------------------------------
// 📄 ADVANCED REPORT EXPORTER – MULTI-METRIC ANALYTICS + DYNAMIC LAYOUT
// -----------------------------------------------------------------------------

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' show BuildContext;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'package:intl/intl.dart';
import '../models/job_model.dart';
import '../models/user_model.dart';

class ReportExporter {
  static Future<pw.Font> _fontRegular() async {
    final data = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    return pw.Font.ttf(data);
  }

  static Future<pw.Font> _fontBold() async {
    final data = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    return pw.Font.ttf(data);
  }

  // ---------------------------------------------------------
  /// PDF EXPORT – NEW AGNOSTIC VERSION
  // ---------------------------------------------------------
  static Future<bool> exportToPdf({
    required BuildContext context,
    required List<Job> jobs,
    required List<AppUser> users,
    required String title,
  }) async {
    try {
      final font = await _fontRegular();
      final bold = await _fontBold();

      Uint8List? logoBytes;
      try {
        logoBytes = (await rootBundle.load("assets/logo.png")).buffer.asUint8List();
      } catch (_) {}

      final pdf = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: bold));

      // Metrics Calculation
      double totalDistance = 0;
      double totalWeight = 0;
      Map<String, int> driverJobs = {};
      Map<String, String> driverNames = {};
      
      for (var u in users) {
        if (u.role == "driver") driverNames[u.uid] = u.name;
      }

      for (var j in jobs) {
        totalDistance += j.distanceKm;
        totalWeight += j.cargoWeightKg;
        final dId = j.driverId;
        if (dId.isNotEmpty) driverJobs[dId] = (driverJobs[dId] ?? 0) + 1;
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => _buildHeader(title, logoBytes),
          footer: (context) => _buildFooter(context),
          build: (context) => [
            pw.SizedBox(height: 20),
            _buildKpiGrid(jobs.length, totalDistance, totalWeight),
            pw.SizedBox(height: 30),
            pw.Text("Sürücü Performans Özeti", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 10),
            _buildDriverTable(driverJobs, driverNames),
            pw.SizedBox(height: 30),
            pw.Text("Son Operasyonlar", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 10),
            _buildJobsTable(jobs),
          ],
        ),
      );

      final path = await FilePicker.platform.saveFile(
        dialogTitle: "PDF Kaydet",
        fileName: "operasyon_raporu_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf",
        allowedExtensions: ["pdf"],
        type: FileType.custom,
      );

      if (path == null) return false;
      final file = File(path);
      await file.writeAsBytes(await pdf.save());
      return true;
    } catch (e) {
      debugPrint("PDF Export Error: $e");
      return false;
    }
  }

  static pw.Widget _buildHeader(String title, Uint8List? logo) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (logo != null) pw.Container(height: 40, child: pw.Image(pw.MemoryImage(logo))),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text("Oluşturma: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 1, color: PdfColors.blue900),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text("Sayfa ${context.pageNumber} / ${context.pagesCount}", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
    );
  }

  static pw.Widget _buildKpiGrid(int count, double km, double weight) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _kpiBox("Tamamlanan İş", count.toString()),
        _kpiBox("Toplam KM", "${km.toStringAsFixed(0)} KM"),
        _kpiBox("Toplam Tonaj", "${(weight / 1000).toStringAsFixed(1)} T"),
      ],
    );
  }

  static pw.Widget _kpiBox(String label, String value) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.blue100),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.blue900)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        ],
      ),
    );
  }

  static pw.Widget _buildDriverTable(Map<String, int> jobs, Map<String, String> names) {
    final sorted = jobs.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return pw.TableHelper.fromTextArray(
      headers: ["Sürücü", "Tamamlanan İş"],
      data: sorted.take(10).map((e) => [names[e.key] ?? "Bilinmiyor", e.value.toString()]).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
      cellHeight: 25,
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  static pw.Widget _buildJobsTable(List<Job> jobs) {
    return pw.TableHelper.fromTextArray(
      headers: ["Tarih", "Yük", "Mesafe", "Ruta"],
      data: jobs.take(20).map((j) {
        final date = j.timestamps.createdAt ?? DateTime.now();
        return [
          DateFormat('dd.MM.yy').format(date),
          "${j.cargoType} (${j.cargoWeightKg} kg)",
          "${j.distanceKm} km",
          "${j.loadPort} -> ${j.unloadPort}",
        ];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellHeight: 20,
      cellStyle: const pw.TextStyle(fontSize: 9),
    );
  }

  // ---------------------------------------------------------
  /// EXCEL EXPORT
  // ---------------------------------------------------------
  static Future<bool> exportToExcel({
    required BuildContext context,
    required List<Job> jobs,
    required List<AppUser> users,
  }) async {
    try {
      final workbook = Workbook();
      final sheet = workbook.worksheets[0];
      sheet.name = "Operasyon Raporu";

      // Headers
      sheet.getRangeByName('A1').setText('Tarih');
      sheet.getRangeByName('B1').setText('Sürücü ID');
      sheet.getRangeByName('C1').setText('Yük Tipi');
      sheet.getRangeByName('D1').setText('Ağırlık (KG)');
      sheet.getRangeByName('E1').setText('Mesafe (KM)');
      sheet.getRangeByName('F1').setText('Yükleme Limanı');
      sheet.getRangeByName('G1').setText('Boşaltma Limanı');

      final style = workbook.styles.add('HeaderStyle');
      style.bold = true;
      style.backColor = '#DCE6F1';
      sheet.getRangeByName('A1:G1').cellStyle = style;

      for (int i = 0; i < jobs.length; i++) {
        final j = jobs[i];
        final row = i + 2;
        final ts = j.timestamps.createdAt;
        
        if (ts != null) {
          sheet.getRangeByIndex(row, 1).setText(DateFormat('dd.MM.yyyy').format(ts));
        }
        sheet.getRangeByIndex(row, 2).setText(j.driverId);
        sheet.getRangeByIndex(row, 3).setText(j.cargoType);
        sheet.getRangeByIndex(row, 4).setNumber(j.cargoWeightKg);
        sheet.getRangeByIndex(row, 5).setNumber(j.distanceKm);
        sheet.getRangeByIndex(row, 6).setText(j.loadPort);
        sheet.getRangeByIndex(row, 7).setText(j.unloadPort);
      }

      for (int i = 1; i <= 7; i++) {
        sheet.autoFitColumn(i);
      }

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final path = await FilePicker.platform.saveFile(
        dialogTitle: "Excel Kaydet",
        fileName: "operasyon_raporu_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx",
        type: FileType.custom,
        allowedExtensions: ["xlsx"],
      );

      if (path == null) return false;
      await File(path).writeAsBytes(bytes);
      return true;
    } catch (e) {
      debugPrint("Excel Export Error: $e");
      return false;
    }
  }

  // =========================================================
  // DRIVER SPECIFIC EXPORT
  // =========================================================
  
  static Future<bool> exportDriverJobsToPdf({
    required BuildContext context,
    required List<Job> jobs,
  }) async {
    try {
      final font = await _fontRegular();
      final bold = await _fontBold();
      
      Uint8List? logoBytes;
      try {
        logoBytes = (await rootBundle.load("assets/logo.png")).buffer.asUint8List();
      } catch (_) {}

      final pdf = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: bold));

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => _buildHeader("Tamamlanan İşler Raporu", logoBytes),
          footer: (context) => _buildFooter(context),
          build: (context) => [
             pw.SizedBox(height: 20),
            _buildJobsTable(jobs),
          ],
        ),
      );

      final path = await FilePicker.platform.saveFile(
        dialogTitle: "PDF Kaydet",
        fileName: "is_gecmisi_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf",
        allowedExtensions: ["pdf"],
        type: FileType.custom,
      );

      if (path == null) return false;
      final file = File(path);
      await file.writeAsBytes(await pdf.save());
      return true;
    } catch (e) {
      debugPrint("Driver PDF Export Error: $e");
      return false;
    }
  }

  static Future<bool> exportDriverJobsToExcel({
    required BuildContext context,
    required List<Job> jobs,
  }) async {
    try {
      final workbook = Workbook();
      final sheet = workbook.worksheets[0];
      sheet.name = "İş Geçmişi";

      // Headers
      final headers = ["Tarih", "Yük", "Ağırlık (KG)", "Mesafe (KM)", "Yükleme", "Boşaltma"];
      final style = workbook.styles.add('HeaderStyle');
      style.bold = true;
      style.backColor = '#DCE6F1';
      sheet.getRangeByName('A1:F1').cellStyle = style;

      for (int i = 0; i < headers.length; i++) {
        sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
      }

      for (int i = 0; i < jobs.length; i++) {
        final j = jobs[i];
        final row = i + 2;
        
        final date = j.timestamps.createdAt;
        if (date != null) {
          sheet.getRangeByIndex(row, 1).setText(DateFormat('dd.MM.yyyy').format(date));
        }
        
        sheet.getRangeByIndex(row, 2).setText(j.cargoType);
        sheet.getRangeByIndex(row, 3).setNumber(j.cargoWeightKg);
        sheet.getRangeByIndex(row, 4).setNumber(j.distanceKm);
        
        sheet.getRangeByIndex(row, 5).setText(j.loadPort);
        sheet.getRangeByIndex(row, 6).setText(j.unloadPort);
      }

      for (int i = 1; i <= 6; i++) {
        sheet.autoFitColumn(i);
      }

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final path = await FilePicker.platform.saveFile(
        dialogTitle: "Excel Kaydet",
        fileName: "is_gecmisi_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx",
        type: FileType.custom,
        allowedExtensions: ["xlsx"],
      );

      if (path == null) return false;
      await File(path).writeAsBytes(bytes);
      return true;
    } catch (e) {
      debugPrint("Driver Excel Export Error: $e");
      return false;
    }
  }
}
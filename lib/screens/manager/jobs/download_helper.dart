import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class DownloadHelper {
  /// Tek dosya
  static Future<void> downloadOne(BuildContext ctx, String url) async {
    try {
      final fileName =
          "${DateTime.now().millisecondsSinceEpoch}.jpg";

      if (kIsWeb) {
        await launchUrl(Uri.parse(url));
        return;
      }

      if (Platform.isAndroid || Platform.isIOS) {
        await FlutterDownloader.enqueue(
          url: url,
          savedDir: "/storage/emulated/0/Download",
          fileName: fileName,
          showNotification: true,
          openFileFromNotification: true,
        );
        return;
      }

      final folder = await FilePicker.platform.getDirectoryPath(
          dialogTitle: "Klasör Seç:");

      if (folder == null) return;

      final req = await http.get(Uri.parse(url));
      final file = File("$folder/$fileName");
      await file.writeAsBytes(req.bodyBytes);

      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text("Kaydedildi → $folder/$fileName")));
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx)
            .showSnackBar(SnackBar(content: Text("Hata: $e")));
      }
    }
  }

  /// Tüm dosyalar
  static Future<void> downloadAll(BuildContext ctx, List files) async {
    try {
      if (kIsWeb) {
        for (var url in files) {
          await launchUrl(Uri.parse(url));
        }
        return;
      }

      if (Platform.isAndroid || Platform.isIOS) {
        for (var url in files) {
          await FlutterDownloader.enqueue(
            url: url,
            savedDir: "/storage/emulated/0/Download",
            fileName:
            "${DateTime.now().millisecondsSinceEpoch}.jpg",
            showNotification: true,
            openFileFromNotification: true,
          );
        }
        return;
      }

      final folder = await FilePicker.platform.getDirectoryPath(
          dialogTitle: "Kayıt Klasörü Seç");

      if (folder == null) return;

      for (var url in files) {
        final req = await http.get(Uri.parse(url));
        final name =
            "${DateTime.now().microsecondsSinceEpoch}.jpg";
        final file = File("$folder/$name");
        await file.writeAsBytes(req.bodyBytes);
      }

      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text("Tüm dosyalar indirildi → $folder")));
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx)
            .showSnackBar(SnackBar(content: Text("Hata: $e")));
      }
    }
  }
}

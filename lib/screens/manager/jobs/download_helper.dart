import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class DownloadHelper {
  // ===========================================================
  // SINGLE FILE
  // ===========================================================
  static Future<void> downloadOne(
      BuildContext ctx,
      String url, {
        required String fileName,
      }) async {
    try {
      // WEB
      if (kIsWeb) {
        await launchUrl(Uri.parse(url));
        return;
      }

      // MOBILE
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

      // DESKTOP
      final folder = await FilePicker.platform.getDirectoryPath(
        dialogTitle: "Kayıt klasörü seç",
      );

      if (folder == null) return;

      final response = await http.get(Uri.parse(url));
      final file = File("$folder/$fileName");
      await file.writeAsBytes(response.bodyBytes);

      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text("Kaydedildi → $fileName")),
        );
      }
    } catch (e) {
      _error(ctx, e);
    }
  }

  // ===========================================================
  // MULTIPLE FILES
  // ===========================================================
  static Future<void> downloadAll(
      BuildContext ctx,
      List<String> urls,
      String referenceNo,
      ) async {
    try {
      // WEB
      if (kIsWeb) {
        for (final url in urls) {
          await launchUrl(Uri.parse(url));
        }
        return;
      }

      // MOBILE
      if (Platform.isAndroid || Platform.isIOS) {
        for (int i = 0; i < urls.length; i++) {
          await FlutterDownloader.enqueue(
            url: urls[i],
            savedDir: "/storage/emulated/0/Download",
            fileName: "$referenceNo-${i + 1}.jpg",
            showNotification: true,
            openFileFromNotification: true,
          );
        }
        return;
      }

      // DESKTOP
      final folder = await FilePicker.platform.getDirectoryPath(
        dialogTitle: "Kayıt klasörü seç",
      );

      if (folder == null) return;

      for (int i = 0; i < urls.length; i++) {
        final response = await http.get(Uri.parse(urls[i]));
        final file =
        File("$folder/$referenceNo-${i + 1}.jpg");
        await file.writeAsBytes(response.bodyBytes);
      }

      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text("Tüm belgeler indirildi → $referenceNo"),
          ),
        );
      }
    } catch (e) {
      _error(ctx, e);
    }
  }

  // ===========================================================
  // ERROR HANDLER
  // ===========================================================
  static void _error(BuildContext ctx, Object e) {
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text("İndirme hatası: $e")),
    );
  }
}

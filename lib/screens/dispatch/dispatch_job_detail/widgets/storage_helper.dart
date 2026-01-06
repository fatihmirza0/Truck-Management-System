import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class StorageHelper {
  /// Firebase Storage URL'inden download URL al
  static Future<String> getDownloadUrl(String storageUrl) async {
    try {
      // Eğer URL zaten download URL formatındaysa direkt döndür
      if (storageUrl.contains('alt=media')) {
        return storageUrl;
      }

      // Firebase Storage path'inden download URL al
      if (storageUrl.startsWith('gs://')) {
        final ref = FirebaseStorage.instance.refFromURL(storageUrl);
        return await ref.getDownloadURL();
      }

      // Firebase Storage HTTPS URL'inden path çıkar
      if (storageUrl.contains('firebasestorage.googleapis.com')) {
        final uri = Uri.parse(storageUrl);

        // Token varsa direkt kullan
        final token = uri.queryParameters['token'];
        if (token != null) {
          return '${uri.origin}${uri.path}?alt=media&token=$token';
        }

        // Path'den download URL al
        try {
          final path = uri.pathSegments.skip(3).join('/');
          final decodedPath = Uri.decodeComponent(path);
          final ref = FirebaseStorage.instance.ref(decodedPath);
          return await ref.getDownloadURL();
        } catch (e) {
          debugPrint('Path extraction error: $e');
          return storageUrl;
        }
      }

      return storageUrl;
    } catch (e) {
      debugPrint('Download URL error: $e');
      rethrow;
    }
  }

  /// Dosyayı indir - Konum seçme dialogu ile
  static Future<void> downloadFile(String url, String fileName) async {
    try {
      // İzin kontrolü (Android 13+ için)
      if (Platform.isAndroid) {
        // Android 13 ve üzeri için farklı izin kontrolü
        if (await Permission.photos.isGranted ||
            await Permission.manageExternalStorage.isGranted ||
            await Permission.storage.isGranted) {
          // İzin verilmiş
        } else {
          // İzin iste
          final storageStatus = await Permission.storage.request();
          final photosStatus = await Permission.photos.request();

          if (!storageStatus.isGranted && !photosStatus.isGranted) {
            throw Exception('Depolama izni gerekli');
          }
        }
      }

      // Dosya uzantısını URL'den al
      String extension = _getExtensionFromUrl(url);
      final fullFileName = '$fileName$extension';

      // Kullanıcıya kayıt konumu seçtir
      String? selectedPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Dosya kayıt konumunu seçin',
      );

      if (selectedPath == null) {
        // Kullanıcı iptal etti
        throw Exception('İndirme iptal edildi');
      }

      final savePath = '$selectedPath/$fullFileName';

      // Dosyayı indir
      final dio = Dio();
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            debugPrint('Download: ${(received / total * 100).toStringAsFixed(0)}%');
          }
        },
      );

      debugPrint('File downloaded to: $savePath');
    } catch (e) {
      debugPrint('Download file error: $e');
      rethrow;
    }
  }

  /// Hızlı indirme - Downloads klasörüne direkt indir (dialog olmadan)
  static Future<void> quickDownloadFile(String url, String fileName) async {
    try {
      // İzin kontrolü (Android için)
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Depolama izni gerekli');
        }
      }

      // Dosya uzantısını URL'den al
      String extension = _getExtensionFromUrl(url);
      final fullFileName = '$fileName$extension';

      // Download dizinini al
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getDownloadsDirectory();
      }

      if (directory == null) {
        throw Exception('İndirme dizini bulunamadı');
      }

      final savePath = '${directory.path}/$fullFileName';

      // Dosyayı indir
      final dio = Dio();
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            debugPrint('Download: ${(received / total * 100).toStringAsFixed(0)}%');
          }
        },
      );

      debugPrint('File downloaded to: $savePath');
    } catch (e) {
      debugPrint('Download file error: $e');
      rethrow;
    }
  }

  /// URL'den dosya uzantısını çıkar
  static String _getExtensionFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final segments = path.split('/');
      if (segments.isNotEmpty) {
        final fileName = segments.last;
        final parts = fileName.split('.');
        if (parts.length > 1) {
          final ext = parts.last.split('?').first; // Query parametrelerini temizle
          return '.$ext';
        }
      }
    } catch (e) {
      debugPrint('Extension extraction error: $e');
    }

    // Default olarak dosya tipine göre uzantı belirle
    if (url.toLowerCase().contains('.pdf')) return '.pdf';
    if (url.toLowerCase().contains('.jpg') || url.toLowerCase().contains('.jpeg')) return '.jpg';
    if (url.toLowerCase().contains('.png')) return '.png';

    return '.jpg'; // Default
  }

  /// Dosya uzantısından MIME type belirle
  static String getMimeType(String url) {
    final extension = url.split('.').last.toLowerCase().split('?').first;

    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }

  /// Dosya tipine göre ikon döndür
  static IconData getFileIcon(String url) {
    final extension = url.split('.').last.toLowerCase().split('?').first;

    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      default:
        return Icons.insert_drive_file;
    }
  }

  /// Dosya adını URL'den çıkar
  static String getFileName(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final fileName = segments.last.split('?').first;
        return Uri.decodeComponent(fileName);
      }
    } catch (e) {
      debugPrint('File name extraction error: $e');
    }
    return 'Dosya';
  }
}
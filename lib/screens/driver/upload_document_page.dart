import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';

class UploadDocumentsPage extends StatefulWidget {
  final String jobId;
  final String driverId;

  const UploadDocumentsPage({
    super.key,
    required this.jobId,
    required this.driverId,
  });

  @override
  State<UploadDocumentsPage> createState() => _UploadDocumentsPageState();
}

class _UploadDocumentsPageState extends State<UploadDocumentsPage> {
  static const Color primary = Color(0xFF1E3A5F);
  static const Color bg = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF64748B);

  final ImagePicker _picker = ImagePicker();
  final List<XFile> selectedFiles = [];

  bool isUploading = false;
  double uploadProgress = 0.0;

  // ======================================================
  // 📁 GALERİ
  // ======================================================
  Future<void> pickDocuments() async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 75);
      if (files.isNotEmpty) {
        setState(() => selectedFiles.addAll(files));
      }
    } catch (e) {
      debugPrint("Pick Error: $e");
    }
  }

  // ======================================================
  // 📷 KAMERA
  // ======================================================
  Future<void> pickFromCamera() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
      );
      if (photo != null) {
        setState(() => selectedFiles.add(photo));
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  // ======================================================
  // ⬆ UPLOAD & COMPLETE
  // ======================================================
  Future<void> uploadFiles() async {
    if (selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen evrak seçin.")),
      );
      return;
    }

    setState(() {
      isUploading = true;
      uploadProgress = 0.0;
    });

    try {
      final jobRef = FirebaseFirestore.instance.collection("jobs").doc(widget.jobId);
      final jobSnap = await jobRef.get();

      if (!jobSnap.exists) {
        throw "Job bulunamadı";
      }

      final jobData = (jobSnap.data() as Map<String, dynamic>?) ?? {};

      // Zaten completed ise double submit engelle
      final status = (jobData["status"] ?? "").toString();
      if (status == "completed") {
        throw "Bu iş zaten tamamlanmış.";
      }

      final List<String> urls = [];

      // Dosyaları yükle
      for (int i = 0; i < selectedFiles.length; i++) {
        final file = selectedFiles[i];

        final path =
            "jobDocuments/${widget.jobId}/${DateTime.now().millisecondsSinceEpoch}_${file.name}";
        final ref = FirebaseStorage.instance.ref().child(path);

        final uploadTask = ref.putFile(File(file.path));
        uploadTask.snapshotEvents.listen((snap) {
          final p = snap.totalBytes == 0
              ? 0.0
              : snap.bytesTransferred / snap.totalBytes;
          if (!mounted) return;
          setState(() {
            uploadProgress = (i / selectedFiles.length) + (p / selectedFiles.length);
          });
        });

        await uploadTask;
        urls.add(await ref.getDownloadURL());
      }

      // Batch işlem - Hem job'u completed yap hem driver'ı available
      final batch = FirebaseFirestore.instance.batch();

      // 1. Job'u güncelle
      batch.update(jobRef, {
        "documents": FieldValue.arrayUnion(urls),
        "status": "completed",
        "timestamps.completedAt": FieldValue.serverTimestamp(),
      });

      // 2. Driver'ı available yap ⭐
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.driverId);

      batch.update(userRef, {
        "jobStatus": "available",
        "currentJobId": null,
      });

      await batch.commit();

      if (!mounted) return;
      await _successDialog();

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint("UPLOAD ERROR → $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Hata: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  // ======================================================
  // ✅ SUCCESS DIALOG
  // ======================================================
  Future<void> _successDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: SizedBox(
              height: 300,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.network(
                    "https://assets9.lottiefiles.com/packages/lf20_jbrw3hcz.json",
                    height: 120,
                    repeat: false,
                    onLoaded: (composition) {
                      Future.delayed(composition.duration, () {
                        if (Navigator.canPop(dialogContext)) {
                          Navigator.of(dialogContext).pop();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "İş Tamamlandı! 🎉",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Evraklar başarıyla yüklendi.",
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Text(
                          "Durum: Müsait",
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ======================================================
  // UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text(
          "Evrak Yükleme",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),

          // Info Banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Evrakları yükleyip tamamladığınızda durumunuz 'Müsait' olacak.",
                    style: TextStyle(fontSize: 13, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isUploading ? null : pickDocuments,
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Galeriden Seç"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isUploading ? null : pickFromCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Kamera"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // File Grid
          Expanded(
            child: selectedFiles.isEmpty
                ? _emptyState()
                : GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: selectedFiles.length,
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemBuilder: (_, i) {
                final file = selectedFiles[i];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(file.path),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => selectedFiles.removeAt(i)),
                        child: const CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.black54,
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Progress / Submit
          Padding(
            padding: const EdgeInsets.all(16),
            child: isUploading
                ? Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Yükleniyor...",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "%${(uploadProgress * 100).toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: uploadProgress,
                    minHeight: 10,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation(primary),
                  ),
                ),
              ],
            )
                : ElevatedButton.icon(
              onPressed: uploadFiles,
              icon: const Icon(Icons.check_circle),
              label: const Text(
                "Yüklemeyi Tamamla",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.upload_file_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            "Henüz evrak seçilmedi",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Galeriden veya kameradan belge ekleyin",
            style: TextStyle(
              color: textMuted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
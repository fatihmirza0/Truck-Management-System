import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';

class UploadDocumentsPage extends StatefulWidget {
  final String jobId;

  const UploadDocumentsPage({super.key, required this.jobId});

  @override
  State<UploadDocumentsPage> createState() => _UploadDocumentsPageState();
}

class _UploadDocumentsPageState extends State<UploadDocumentsPage> {
  // ======================================================
  // UI TOKENS (DİĞER SAYFALARLA AYNI)
  // ======================================================
  static const Color primary = Color(0xFF1E3A5F);
  static const Color bg = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textDark = Color(0xFF0F172A);
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
      final photo =
      await _picker.pickImage(source: ImageSource.camera, imageQuality: 75);
      if (photo != null) {
        setState(() => selectedFiles.add(photo));
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  // ======================================================
  // ⬆ UPLOAD
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
      final jobRef =
      FirebaseFirestore.instance.collection("jobs").doc(widget.jobId);
      final jobSnap = await jobRef.get();

      if (!jobSnap.exists) {
        throw "Job bulunamadı";
      }

      final jobData = (jobSnap.data() as Map<String, dynamic>?) ?? {};
      final driverUid = (jobData["driverId"] ?? "").toString();
      if (driverUid.isEmpty) throw "driverId bulunamadı";

      // (opsiyonel) zaten completed ise double submit engelle
      final status = (jobData["status"] ?? "").toString();
      if (status == "completed") {
        throw "Bu iş zaten tamamlanmış görünüyor.";
      }

      final List<String> urls = [];

      for (int i = 0; i < selectedFiles.length; i++) {
        final file = selectedFiles[i];

        final path =
            "jobDocuments/${widget.jobId}/${DateTime.now().millisecondsSinceEpoch}_${file.name}";
        final ref = FirebaseStorage.instance.ref().child(path);

        final uploadTask = ref.putFile(File(file.path));
        uploadTask.snapshotEvents.listen((snap) {
          final p = snap.totalBytes == 0 ? 0.0 : snap.bytesTransferred / snap.totalBytes;
          if (!mounted) return;
          setState(() {
            uploadProgress =
                (i / selectedFiles.length) + (p / selectedFiles.length);
          });
        });

        await uploadTask;
        urls.add(await ref.getDownloadURL());
      }

      // ✅ Job update (new schema)
      await jobRef.update({
        "documents": FieldValue.arrayUnion(urls), // senin mevcut kullanımın
        "status": "completed",
        "timestamps.completedAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      await _successDialog();

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint("UPLOAD ERROR → $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Hata: $e")));
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
              height: 260,
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
                    "İş Tamamlandı",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text("Evraklar başarıyla yüklendi."),
                  const SizedBox(height: 16),
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
        foregroundColor: textDark,
        elevation: 0,
        title: const Text(
          "Evrak Yükleme",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),

          // ===================================================
          // ACTION BUTTONS
          // ===================================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isUploading ? null : pickDocuments,
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Galeriden Seç"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isUploading ? null : pickFromCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Kamera"),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ===================================================
          // FILE LIST
          // ===================================================
          Expanded(
            child: selectedFiles.isEmpty
                ? _emptyState()
                : GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: selectedFiles.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                          child: Icon(Icons.close,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // ===================================================
          // PROGRESS / SUBMIT
          // ===================================================
          Padding(
            padding: const EdgeInsets.all(16),
            child: isUploading
                ? Column(
              children: [
                Text(
                  "%${(uploadProgress * 100).toStringAsFixed(0)}",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: uploadProgress,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(10),
                ),
              ],
            )
                : ElevatedButton(
              onPressed: uploadFiles,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: primary,
              ),
              child: const Text(
                "Yüklemeyi Tamamla",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
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
          Icon(Icons.upload_file_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Text(
            "Henüz evrak seçilmedi",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            "Galeriden veya kameradan belge ekleyin",
            style: TextStyle(color: textMuted),
          ),
        ],
      ),
    );
  }
}

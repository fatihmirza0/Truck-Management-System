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
  final ImagePicker _picker = ImagePicker();
  List<XFile> selectedFiles = [];

  bool isUploading = false;
  double uploadProgress = 0.0;

  // ---------------------------------------------------------------------------
  // 📌 Çoklu Galeri Seçimi
  // ---------------------------------------------------------------------------
  Future<void> pickDocuments() async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 70);

      if (files.isNotEmpty) {
        setState(() => selectedFiles.addAll(files));
      }
    } catch (e) {
      debugPrint("Pick Error: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // 📷 Kamera ile Fotoğraf
  // ---------------------------------------------------------------------------
  Future<void> pickFromCamera() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );

      if (photo != null) {
        setState(() => selectedFiles.add(photo));
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // ⬆ Belgeleri Upload Et + Firestore'a Kaydet
  // ---------------------------------------------------------------------------
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

    List<String> documentUrls = [];

    try {
      for (int i = 0; i < selectedFiles.length; i++) {
        final file = selectedFiles[i];

        final fileName =
            "${DateTime.now().millisecondsSinceEpoch}_${file.name}";

        final ref = FirebaseStorage.instance
            .ref()
            .child("jobDocuments/${widget.jobId}/$fileName");

        UploadTask task = ref.putFile(File(file.path));

        task.snapshotEvents.listen((snapshot) {
          final progress =
              snapshot.bytesTransferred / snapshot.totalBytes;

          setState(() {
            uploadProgress =
                (i / selectedFiles.length) +
                    (progress / selectedFiles.length);
          });
        });

        await task;

        final url = await ref.getDownloadURL();
        documentUrls.add(url);
      }

      // ---------------------------------------------------------------------
      // 🔥 JOB DÖKÜMANLARINI GÜNCELLE
      // ---------------------------------------------------------------------
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update({
        "documents": FieldValue.arrayUnion(documentUrls),
        "status": "completed",
        "completedAt": FieldValue.serverTimestamp(),
      });

      // ---------------------------------------------------------------------
      // 🎉 BAŞARI ANİMASYONU
      // ---------------------------------------------------------------------
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Lottie.network(
              "https://assets9.lottiefiles.com/packages/lf20_ukrppx.json",
              repeat: false,
            ),
          ),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) Navigator.pop(context);
      if (mounted) Navigator.pop(context);

    } catch (e) {
      debugPrint("UPLOAD ERROR: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata oluştu: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isUploading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 🖼 Fotoğraf Önizleme
  // ---------------------------------------------------------------------------
  void openPreview(XFile file) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 400,
          child: Column(
            children: [
              Expanded(
                child: Image.file(
                  File(file.path),
                  fit: BoxFit.cover,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Kapat"),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ❌ Fotoğraf Silme
  // ---------------------------------------------------------------------------
  void removeFile(int index) {
    setState(() => selectedFiles.removeAt(index));
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Evrak Yükleme"),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),

          // Kamera + Galeri
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isUploading ? null : pickDocuments,
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Galeriden Seç"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isUploading ? null : pickFromCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Kamera"),
                  ),
                ),
              ],
            ),
          ),

          // Grid
          Expanded(
            child: selectedFiles.isEmpty
                ? const Center(
              child: Text("Henüz evrak seçilmedi."),
            )
                : GridView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: selectedFiles.length,
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, i) {
                final file = selectedFiles[i];

                return Stack(
                  children: [
                    GestureDetector(
                      onTap: () => openPreview(file),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(file.path),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ),

                    // Sil butonu
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => removeFile(i),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Yükleme Progress
          isUploading
              ? Column(
            children: [
              Text(
                "%${(uploadProgress * 100).toStringAsFixed(0)}",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.all(16),
                child: LinearProgressIndicator(
                  value: uploadProgress,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          )
              : Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: uploadFiles,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.green,
              ),
              child: const Text(
                "Yüklemeyi Tamamla",
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

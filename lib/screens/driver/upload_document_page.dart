import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart'; // ⭐ LOTTIE EKLENDİ

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

  // --------------------------------------------------------
  // GALERİDEN ÇOKLU SEÇİM
  // --------------------------------------------------------
  Future<void> pickDocuments() async {
    try {
      final files = await _picker.pickMultiImage();

      if (files != null && files.isNotEmpty) {
        setState(() => selectedFiles.addAll(files));
      }
    } catch (e) {
      print("Pick Error: $e");
    }
  }

  // --------------------------------------------------------
  // KAMERA
  // --------------------------------------------------------
  Future<void> pickFromCamera() async {
    try {
      final photo = await _picker.pickImage(source: ImageSource.camera);

      if (photo != null) {
        setState(() => selectedFiles.add(photo));
      }
    } catch (e) {
      print("Camera Error: $e");
    }
  }

  // --------------------------------------------------------
  // UPLOAD FILES + YÜZDE + FIRESTORE
  // --------------------------------------------------------
  Future<void> uploadFiles() async {
    if (selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen evrak yükleyin.")),
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
          double progress =
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

      // 🔥 FIRESTORE'A KAYDET
      final jobRef =
      FirebaseFirestore.instance.collection('jobs').doc(widget.jobId);

      await jobRef.update({
        "documents": FieldValue.arrayUnion(documentUrls),
        "status": "completed",
        "completedAt": FieldValue.serverTimestamp(),
      });

      // ---------------------------------------------------
      // 🎉 BAŞARI ANİMASYONU (Yumuşak geçiş)
      // ---------------------------------------------------
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

      Navigator.pop(context); // animasyon pop
      Navigator.pop(context); // sayfa pop

    } catch (e) {
      print("UPLOAD ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: $e")),
      );
    } finally {
      setState(() => isUploading = false);
    }
  }

  // --------------------------------------------------------
  // PREVIEW
  // --------------------------------------------------------
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

  // --------------------------------------------------------
  // REMOVE FILE
  // --------------------------------------------------------
  void removeFile(int index) {
    setState(() => selectedFiles.removeAt(index));
  }

  // --------------------------------------------------------
  // UI
  // --------------------------------------------------------
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
                ? const Center(child: Text("Henüz evrak seçilmedi."))
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

                    // Sil
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

          // Progress
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

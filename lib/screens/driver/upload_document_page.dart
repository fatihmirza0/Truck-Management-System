// ---------------------------------------------------------------------------
// UPLOAD DOCUMENTS PAGE – DIALOG FIXED VERSION
// ---------------------------------------------------------------------------

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
      final files = await _picker.pickMultiImage(imageQuality: 75);
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
      final photo =
      await _picker.pickImage(imageQuality: 75, source: ImageSource.camera);
      if (photo != null) {
        setState(() => selectedFiles.add(photo));
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // ⬆ Belgeleri Upload Et + Firestore Güncelle
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
      // ---------------------------------------------------------
      // 1) JOB → assignedToUid (şoför UID) al
      // ---------------------------------------------------------
      final jobRef =
      FirebaseFirestore.instance.collection("jobs").doc(widget.jobId);
      final jobSnap = await jobRef.get();

      final String? driverUid = jobSnap.data()?["assignedToUid"];

      if (driverUid == null) {
        throw "Job içinde assignedToUid bulunamadı!";
      }

      // ---------------------------------------------------------
      // 2) Dosyaları sırayla yükle
      // ---------------------------------------------------------
      for (int i = 0; i < selectedFiles.length; i++) {
        final file = selectedFiles[i];

        final path =
            "jobDocuments/${widget.jobId}/${DateTime.now().millisecondsSinceEpoch}_${file.name}";
        final ref = FirebaseStorage.instance.ref().child(path);

        final uploadTask = ref.putFile(File(file.path));

        uploadTask.snapshotEvents.listen((snapshot) {
          final p = snapshot.bytesTransferred / snapshot.totalBytes;
          setState(() => uploadProgress =
              (i / selectedFiles.length) + (p / selectedFiles.length));
        });

        await uploadTask;
        final url = await ref.getDownloadURL();
        documentUrls.add(url);
      }

      // ---------------------------------------------------------
      // 3) JOB durumunu güncelle + doküman ekle
      // ---------------------------------------------------------
      await jobRef.update({
        "documents": FieldValue.arrayUnion(documentUrls),
        "status": "completed",
        "completedAt": FieldValue.serverTimestamp(),
      });

      // ---------------------------------------------------------
      // 4) Şoförü tekrar müsait yap
      // ---------------------------------------------------------
      await FirebaseFirestore.instance
          .collection("users")
          .doc(driverUid)
          .update({"jobStatus": "available"});

      // ---------------------------------------------------------
      // 5) BAŞARI ANİMASYONU - DÜZELTİLMİŞ VERSİYON
      // ---------------------------------------------------------
      if (!mounted) return;

      // Dialog göster ve kapandığında devam et
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => WillPopScope(
          onWillPop: () async => false, // Geri tuşunu engelle
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: SizedBox(
              width: 250,
              height: 280,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.network(
                    "https://assets9.lottiefiles.com/packages/lf20_jbrw3hcz.json",
                    height: 120,
                    repeat: false,
                    onLoaded: (composition) {
                      // Animasyon bitince otomatik kapat
                      Future.delayed(composition.duration, () {
                        if (Navigator.canPop(dialogContext)) {
                          Navigator.of(dialogContext).pop();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "İş Tamamlandı!",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text("Evraklar başarıyla yüklendi."),
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
      );

      // Dialog kapandıktan sonra
      if (!mounted) return;

      // Küçük delay ekle
      await Future.delayed(const Duration(milliseconds: 300));

      // ---------------------------------------
      // 🚀 YÖNLENDİRME - DriverScreen'e geri dön
      // ---------------------------------------
      if (!mounted) return;

      // Tüm sayfaları kapat ve DriverScreen'e dön
      // UploadDocumentsPage'i kapat
      Navigator.of(context).pop();

    } catch (e) {
      debugPrint("UPLOAD ERROR → $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata oluştu: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 🖼 Fotoğraf Önizleme
  // ---------------------------------------------------------------------------
  void openPreview(XFile file) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Image.file(File(file.path), fit: BoxFit.cover),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ❌ Fotoğraf Sil
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
      appBar: AppBar(title: const Text("Evrak Yükleme")),
      body: Column(
        children: [
          const SizedBox(height: 10),

          // GALERİ + KAMERA
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

          // FOTO LISTESI
          Expanded(
            child: selectedFiles.isEmpty
                ? const Center(child: Text("Henüz evrak seçilmedi."))
                : GridView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: selectedFiles.length,
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemBuilder: (_, i) {
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
                    Positioned(
                      right: 4,
                      top: 4,
                      child: GestureDetector(
                        onTap: () => removeFile(i),
                        child: const CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close,
                              size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // PROGRESS + BUTON
          isUploading
              ? Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  "%${(uploadProgress * 100).toStringAsFixed(0)}",
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: uploadProgress,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(12),
                ),
              ],
            ),
          )
              : Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: uploadFiles,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.green,
              ),
              child: const Text("Yüklemeyi Tamamla",
                  style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
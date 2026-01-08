import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/info_banner.dart';
import '../widgets/action_buttons.dart';
import '../widgets/file_grid_item.dart';
import '../widgets/empty_state.dart';
import '../widgets/upload_progress.dart';
import '../widgets/submit_button.dart';
import '../widgets/success_dialog.dart';

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
  static const Color bg = Color(0xFFF8FAFC);

  final ImagePicker _picker = ImagePicker();
  final List<XFile> selectedFiles = [];

  bool isUploading = false;
  double uploadProgress = 0.0;

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

      final jobData = jobSnap.data() ?? {};

      final status = (jobData["status"] ?? "").toString();
      if (status == "completed") {
        throw "Bu iş zaten tamamlanmış.";
      }

      final List<String> urls = [];

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
            uploadProgress =
                (i / selectedFiles.length) + (p / selectedFiles.length);
          });
        });

        await uploadTask;
        urls.add(await ref.getDownloadURL());
      }

      final batch = FirebaseFirestore.instance.batch();

      batch.update(jobRef, {
        "documents": FieldValue.arrayUnion(urls),
        "status": "completed",
        "timestamps.completedAt": FieldValue.serverTimestamp(),
      });

      final userRef =
          FirebaseFirestore.instance.collection('users').doc(widget.driverId);

      batch.update(userRef, {
        "jobStatus": "available",
        "currentJobId": null,
      });

      await batch.commit();
      await FirebaseDatabase.instance
          .ref("locations/${widget.driverId}")
          .update({
        "status": "online",
        "timestamp": ServerValue.timestamp,
      });

      if (!mounted) return;
      await SuccessDialog.show(context);
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
          const InfoBanner(),
          const SizedBox(height: 16),
          ActionButtons(
            isUploading: isUploading,
            onPickDocuments: pickDocuments,
            onPickFromCamera: pickFromCamera,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: selectedFiles.isEmpty
                ? const EmptyState()
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
                      return FileGridItem(
                        file: file,
                        onRemove: () =>
                            setState(() => selectedFiles.removeAt(i)),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: isUploading
                ? UploadProgress(progress: uploadProgress)
                : SubmitButton(onPressed: uploadFiles),
          ),
        ],
      ),
    );
  }
}


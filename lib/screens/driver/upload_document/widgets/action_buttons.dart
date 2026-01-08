// 📁 lib/screens/driver/upload_document/widgets/action_buttons.dart
import 'package:flutter/material.dart';

class ActionButtons extends StatelessWidget {
  final bool isUploading;
  final VoidCallback onPickDocuments;
  final VoidCallback onPickFromCamera;

  const ActionButtons({
    super.key,
    required this.isUploading,
    required this.onPickDocuments,
    required this.onPickFromCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isUploading ? null : onPickDocuments,
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
              onPressed: isUploading ? null : onPickFromCamera,
              icon: const Icon(Icons.camera_alt),
              label: const Text("Kamera"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



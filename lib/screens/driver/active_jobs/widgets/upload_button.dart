// 📁 lib/screens/driver/active_jobs/widgets/upload_button.dart
import 'package:flutter/material.dart';
import '../../upload_document/pages/upload_document_page.dart';

class UploadButton extends StatelessWidget {
  final String jobId;
  final String driverId;

  const UploadButton({
    super.key,
    required this.jobId,
    required this.driverId,
  });

  static const Color primary = Color(0xFF1E3A5F);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UploadDocumentsPage(
                jobId: jobId,
                driverId: driverId,
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          "Evrak Yükle ve İşi Tamamla",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}




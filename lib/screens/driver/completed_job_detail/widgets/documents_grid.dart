// 📁 lib/screens/driver/completed_job_detail/widgets/documents_grid.dart
import 'package:flutter/material.dart';
import 'detail_card.dart';
import '../../../dispatch/dispatch_job_detail/widgets/storage_helper.dart';

class DocumentsGrid extends StatelessWidget {
  final List<String> documents;

  const DocumentsGrid({
    super.key,
    required this.documents,
  });

  static const Color textMuted = Color(0xFF64748B);
  static const Color bg = Color(0xFFF8FAFC);

  void _openImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return DetailCard(
        child: Column(
          children: const [
            Icon(Icons.insert_drive_file_outlined, size: 42, color: textMuted),
            SizedBox(height: 10),
            Text(
              "Bu iş için evrak yüklenmemiş",
              style: TextStyle(
                fontSize: 13,
                color: textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return DetailCard(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: documents.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemBuilder: (context, i) {
          final url = documents[i];
          return FutureBuilder<String>(
            future: StorageHelper.getDownloadUrl(url),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              
              final displayUrl = snapshot.data ?? url;

              return GestureDetector(
                onTap: () => _openImage(context, displayUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    color: bg,
                    child: Image.network(
                      displayUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: textMuted,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}




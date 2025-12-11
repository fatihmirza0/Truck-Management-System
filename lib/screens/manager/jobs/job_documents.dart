import 'package:flutter/material.dart';
import 'full_screen_gallery.dart';
import 'download_helper.dart';

// ============================================
// MODERN DOCUMENT VIEWER
// Daha iyi buton yerleşimi ve tasarım
// ============================================

class JobDocuments extends StatelessWidget {
  final List documents;

  const JobDocuments({super.key, required this.documents});

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            "Belge yok",
            style: TextStyle(
              color: Color(0xFF718096),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(context),
        const SizedBox(height: 16),
        _grid(context),
      ],
    );
  }

  Widget _header(BuildContext ctx) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Row(
        children: [
          Icon(Icons.attachment_outlined, size: 20, color: Color(0xFF4A5568)),
          SizedBox(width: 8),
          Text(
            "Belgeler",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
        ],
      ),
      if (documents.length > 1)
        TextButton.icon(
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text("Tümünü indir"),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF2C5282),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => DownloadHelper.downloadAll(ctx, documents),
        )
    ],
  );

  Widget _grid(BuildContext ctx) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1,
    ),
    itemCount: documents.length,
    itemBuilder: (c, i) => _item(ctx, documents[i], i),
  );

  Widget _item(BuildContext ctx, String url, int index) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Image
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) => FullScreenGalleryViewer(
                    images: documents,
                    initialIndex: index,
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFF7FAFC),
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        size: 48,
                        color: Color(0xFFCBD5E0),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Overlay gradient for better button visibility
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                  ],
                  stops: const [0.6, 1.0],
                ),
              ),
            ),
          ),

          // Download button - Alt ortada
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => DownloadHelper.downloadOne(ctx, url),
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.download_rounded,
                        color: Color(0xFF2C5282),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
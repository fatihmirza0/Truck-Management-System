import 'package:flutter/material.dart';
import 'download_helper.dart';

class FullScreenGalleryViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String referenceNo;

  const FullScreenGalleryViewer({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.referenceNo,
  });

  @override
  State<FullScreenGalleryViewer> createState() =>
      _FullScreenGalleryViewerState();
}

class _FullScreenGalleryViewerState
    extends State<FullScreenGalleryViewer> {
  late PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: _currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (c, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  widget.images[i],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      _errorPlaceholder(),
                ),
              ),
            ),
          ),

          // TOP BAR
          Positioned(
            top: 40,
            left: 20,
            child: _iconBtn(
              Icons.close,
                  () => Navigator.pop(context),
            ),
          ),

          Positioned(
            top: 40,
            right: 20,
            child: _iconBtn(
              Icons.download_rounded,
                  () => _downloadCurrent(context),
            ),
          ),

          // INDEX INDICATOR
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${_currentIndex + 1} / ${widget.images.length}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _downloadCurrent(BuildContext ctx) {
    final fileName =
        "${widget.referenceNo}-${_currentIndex + 1}.jpg";

    DownloadHelper.downloadOne(
      ctx,
      widget.images[_currentIndex],
      fileName: fileName,
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.black.withValues(alpha: .5),
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap,
      ),
    );
  }

  Widget _errorPlaceholder() => const Center(
    child: Icon(
      Icons.broken_image_outlined,
      size: 64,
      color: Colors.white54,
    ),
  );
}

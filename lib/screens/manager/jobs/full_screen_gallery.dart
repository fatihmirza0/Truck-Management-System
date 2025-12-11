import 'package:flutter/material.dart';

class FullScreenGalleryViewer extends StatefulWidget {
  final List images;
  final int initialIndex;

  const FullScreenGalleryViewer({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<FullScreenGalleryViewer> createState() =>
      _FullScreenGalleryViewerState();
}

class _FullScreenGalleryViewerState extends State<FullScreenGalleryViewer> {
  late PageController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: ctrl,
            itemCount: widget.images.length,
            itemBuilder: (c, i) => InteractiveViewer(
              child: Image.network(widget.images[i], fit: BoxFit.contain),
            ),
          ),
          Positioned(
            right: 20,
            top: 40,
            child: IconButton(
              icon:
              const Icon(Icons.close, size: 30, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

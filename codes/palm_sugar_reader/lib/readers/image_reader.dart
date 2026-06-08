import 'dart:io';
import 'package:flutter/material.dart';

/// 图片阅读器 — 支持缩放、平移
class ImageReader extends StatefulWidget {
  final String filePath;

  const ImageReader({super.key, required this.filePath});

  @override
  State<ImageReader> createState() => _ImageReaderState();
}

class _ImageReaderState extends State<ImageReader> {
  final TransformationController _transformationController =
      TransformationController();
  bool _isZoomed = false;

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
    setState(() => _isZoomed = false);
  }

  void _toggleZoom() {
    if (_isZoomed) {
      _resetZoom();
    } else {
      _transformationController.value = Matrix4.diagonal3Values(2.0, 2.0, 1.0);
      setState(() => _isZoomed = true);
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transformationController,
        panEnabled: true,
        scaleEnabled: true,
        minScale: 0.5,
        maxScale: 5.0,
        boundaryMargin: const EdgeInsets.all(20),
        child: Center(
          child: Image.file(
            File(widget.filePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('无法加载图片', style: TextStyle(color: Colors.grey)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

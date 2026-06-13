import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../theme.dart';

/// PDF 阅读器 — 基于 pdfrx，支持缩放、滚动、文字选择
class PdfReader extends StatefulWidget {
  final String filePath;

  const PdfReader({super.key, required this.filePath});

  @override
  State<PdfReader> createState() => _PdfReaderState();
}

class _PdfReaderState extends State<PdfReader> {
  final PdfViewerController _controller = PdfViewerController();

  void _zoomIn() {
    _controller.zoomUp(
      duration: const Duration(milliseconds: 150),
    );
  }

  void _zoomOut() {
    _controller.zoomDown(
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PdfViewer.file(
          widget.filePath,
          controller: _controller,
          params: PdfViewerParams(
            backgroundColor: Colors.grey.shade200,
            enableTextSelection: true,
            pageAnchor: PdfPageAnchor.all,
            margin: 8,
          ),
        ),
        // 缩放按钮
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ZoomButton(
                icon: Icons.add,
                onPressed: _zoomIn,
                tooltip: '放大',
              ),
              const SizedBox(height: 8),
              _ZoomButton(
                icon: Icons.remove,
                onPressed: _zoomOut,
                tooltip: '缩小',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 缩放按钮小部件
class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _ZoomButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      shape: const CircleBorder(),
      color: AppTheme.primaryColor,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}

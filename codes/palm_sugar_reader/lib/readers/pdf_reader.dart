import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// PDF 阅读器 — 基于 pdfrx，支持缩放、滚动、文字选择
class PdfReader extends StatelessWidget {
  final String filePath;

  const PdfReader({super.key, required this.filePath});

  @override
  Widget build(BuildContext context) {
    return PdfViewer.file(
      filePath,
      params: PdfViewerParams(
        backgroundColor: Colors.grey.shade200,
        enableTextSelection: true,
        pageAnchor: PdfPageAnchor.all,
        margin: 8,
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:epub_view/epub_view.dart' as epub_view;

/// EPUB 阅读器 — 基于 epub_view，支持章节导航与回流排版
class EpubReader extends StatefulWidget {
  final String filePath;

  const EpubReader({super.key, required this.filePath});

  @override
  State<EpubReader> createState() => _EpubReaderState();
}

class _EpubReaderState extends State<EpubReader> {
  epub_view.EpubController? _epubController;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEpub();
  }

  Future<void> _loadEpub() async {
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();

      // 在后台 isolate-friendly 的 Future 中解析 EPUB
      final document = Future(() => epub_view.EpubReader.readBook(bytes));

      _epubController = epub_view.EpubController(document: document);

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _epubController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('读取失败: $_error', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return epub_view.EpubView(
      controller: _epubController!,
      onDocumentLoaded: (document) {
        debugPrint('EPUB loaded: ${document.Title}');
      },
      onDocumentError: (error) {
        debugPrint('EPUB error: $error');
      },
      builders: epub_view.EpubViewBuilders<epub_view.DefaultBuilderOptions>(
        options: const epub_view.DefaultBuilderOptions(),
        chapterDividerBuilder: (_) => const Divider(height: 1),
      ),
    );
  }
}

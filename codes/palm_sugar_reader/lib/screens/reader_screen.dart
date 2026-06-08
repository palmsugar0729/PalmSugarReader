import 'package:flutter/material.dart';
import '../models/book.dart';
import '../readers/image_reader.dart';
import '../readers/txt_reader.dart';
import '../readers/markdown_reader.dart';
import '../readers/epub_reader.dart';
import '../readers/pdf_reader.dart';

/// 阅读器路由壳 — 根据文件格式分发到对应阅读器
class ReaderScreen extends StatelessWidget {
  final Book book;

  const ReaderScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(book.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // TODO: 更多操作（书签、分享等）
            },
          ),
        ],
      ),
      body: _buildReader(),
    );
  }

  Widget _buildReader() {
    return switch (book.format) {
      BookFormat.image => ImageReader(filePath: book.filePath),
      BookFormat.txt => TxtReader(filePath: book.filePath),
      BookFormat.markdown => MarkdownReader(filePath: book.filePath),
      BookFormat.pdf => PdfReader(filePath: book.filePath),
      BookFormat.epub => EpubReader(filePath: book.filePath),
      BookFormat.unknown => _buildPlaceholder('不支持的文件格式'),
    };
  }

  Widget _buildPlaceholder(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.construction, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

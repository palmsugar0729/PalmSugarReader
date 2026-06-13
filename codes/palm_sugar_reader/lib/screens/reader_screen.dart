import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../converters/format_converter.dart';
import '../models/book.dart';
import '../readers/image_reader.dart';
import '../readers/txt_reader.dart';
import '../readers/markdown_reader.dart';
import '../readers/epub_reader.dart';
import '../readers/pdf_reader.dart';
import '../theme.dart';

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
          _buildConvertMenu(context),
        ],
      ),
      body: _buildReader(),
    );
  }

  Widget _buildConvertMenu(BuildContext context) {
    final availableTargets = FormatConverter.getAvailableTargets(book.format);

    if (availableTargets.isEmpty) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<BookFormat>(
      icon: const Icon(Icons.more_vert),
      tooltip: '更多操作',
      onSelected: (target) => _startConversion(context, target),
      itemBuilder: (context) {
        return [
          const PopupMenuItem<BookFormat>(
            enabled: false,
            child: Text(
              '格式转换',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          ...availableTargets.map(
            (target) => PopupMenuItem<BookFormat>(
              value: target,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  target == BookFormat.markdown
                      ? Icons.code
                      : target == BookFormat.txt
                          ? Icons.description
                          : Icons.picture_as_pdf,
                  color: AppTheme.primaryDark,
                ),
                title: Text('转为 ${target.displayName}'),
                subtitle: Text(
                  _conversionDescription(book.format, target),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        ];
      },
    );
  }

  String _conversionDescription(BookFormat source, BookFormat target) {
    if (source == BookFormat.txt && target == BookFormat.markdown) {
      return '自动检测编码，添加元数据';
    }
    if (source == BookFormat.markdown && target == BookFormat.txt) {
      return '剥离格式，提取纯文本';
    }
    if (source == BookFormat.epub && target == BookFormat.markdown) {
      return '提取章节，转换为 Markdown';
    }
    if (source == BookFormat.markdown && target == BookFormat.pdf) {
      return '渲染为 PDF 文档';
    }
    return '通过 Markdown 中转转换';
  }

  Future<void> _startConversion(
      BuildContext context, BookFormat target) async {
    final sourceFormat = book.format;
    final defaultExt = FormatConverter.targetExtension(target);
    final defaultName = book.title;

    // 1. 选择输出路径
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: '选择 ${target.displayName} 输出位置',
      fileName: '$defaultName.$defaultExt',
      type: FileType.custom,
      allowedExtensions: [defaultExt],
    );

    if (outputPath == null) return; // 用户取消

    // 2. 显示加载状态
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // 3. 执行转换
    final result = await FormatConverter.convert(
      sourcePath: book.filePath,
      source: sourceFormat,
      target: target,
      outputPath: outputPath,
    );

    // 4. 关闭加载
    if (!context.mounted) return;
    Navigator.of(context).pop(); // dismiss loading

    // 5. 显示结果
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('转换成功: ${target.displayName}'),
          backgroundColor: AppTheme.primaryDark,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '打开',
            textColor: Colors.white,
            onPressed: () {
              final convertedBook = Book.fromFile(result.outputPath!);
              if (convertedBook.isReadable) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => ReaderScreen(book: convertedBook),
                  ),
                );
              }
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? '转换失败'),
          backgroundColor: AppTheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
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

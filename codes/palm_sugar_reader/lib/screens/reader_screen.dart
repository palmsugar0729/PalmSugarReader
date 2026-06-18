import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../converters/format_converter.dart';
import '../models/book.dart';
import '../readers/image_reader.dart';
import '../readers/txt_reader.dart';
import '../readers/markdown_reader.dart';
import '../readers/epub_reader.dart';
import '../readers/pdf_reader.dart';
import '../main.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../widgets/top_menu_bar.dart';
import 'settings_screen.dart';

/// 阅读器路由壳 — 根据文件格式分发到对应阅读器
///
/// 顶部菜单栏按钮：
/// - 标注工具（待实现，灰色）
/// - 格式转换（PopMenu 弹出可选目标格式）
/// - 字号（待实现，灰色）
/// - 背景色（待实现，灰色）
/// - 账号（待实现，灰色）
/// - 设置
class ReaderScreen extends StatefulWidget {
  final Book book;

  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  Book get book => widget.book;
  final GlobalKey _convertButtonKey = GlobalKey();
  final GlobalKey<PdfReaderState> _pdfReaderKey = GlobalKey<PdfReaderState>();
  final GlobalKey<EpubReaderState> _epubReaderKey = GlobalKey<EpubReaderState>();
  final GlobalKey<ImageReaderState> _imageReaderKey = GlobalKey<ImageReaderState>();

  void _cycleTheme() {
    final notifier = SettingsProvider.of(context);
    final next = switch (notifier.themeMode) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    };
    notifier.setThemeMode(next);
    SettingsService.save(AppSettings(
      themeMode: next,
      fontSize: notifier.fontSize,
    ));
  }

  void _showAnnotHelp() {
    if (book.format == BookFormat.pdf) {
      _pdfReaderKey.currentState?.enterAnnotationMode();
    } else if (book.format == BookFormat.epub) {
      _epubReaderKey.currentState?.enterAnnotationMode();
    } else if (book.format == BookFormat.image) {
      _imageReaderKey.currentState?.enterAnnotationMode();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前格式不支持标注'), duration: Duration(seconds: 2)),
      );
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  /// 显示格式转换菜单
  void _showConvertMenu() {
    final availableTargets = FormatConverter.getAvailableTargets(book.format);
    if (availableTargets.isEmpty) return;

    final RenderBox? renderBox =
        _convertButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final position = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final size = renderBox?.size ?? const Size(44, 44);

    showMenu<BookFormat>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + size.height,
        position.dx + size.width,
        position.dy + size.height,
      ),
      items: [
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
      ],
    ).then((target) {
      if (target != null && mounted) {
        _startConversion(target);
      }
    });
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

  Future<void> _startConversion(BookFormat target) async {
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
    if (!mounted) return;
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
    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss loading

    // 5. 显示结果
    if (!mounted) return;
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
      BookFormat.image => ImageReader(key: _imageReaderKey, filePath: book.filePath),
      BookFormat.txt => TxtReader(filePath: book.filePath),
      BookFormat.markdown => MarkdownReader(filePath: book.filePath),
      BookFormat.pdf => PdfReader(key: _pdfReaderKey, filePath: book.filePath),
      BookFormat.epub => EpubReader(key: _epubReaderKey, filePath: book.filePath),
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

  @override
  Widget build(BuildContext context) {
    final hasConvertTargets =
        FormatConverter.getAvailableTargets(book.format).isNotEmpty;

    return TopMenuOverlay(
      buttons: [
        TopMenuButton(
          tooltip: '标注工具',
          icon: Icons.edit,
          enabled: book.format == BookFormat.pdf ||
              book.format == BookFormat.epub,
          onPressed: _showAnnotHelp,
        ),
        TopMenuButton(
          tooltip: '格式转换',
          icon: Icons.transform,
          enabled: hasConvertTargets,
          onPressed: _showConvertMenu,
        ),
        const TopMenuButton(
          tooltip: '字号',
          icon: Icons.format_size,
          enabled: false,
        ),
        TopMenuButton(
          tooltip: '背景色',
          icon: Icons.brightness_6,
          onPressed: _cycleTheme,
        ),
        const TopMenuButton(
          tooltip: '账号',
          icon: Icons.person_outline,
          enabled: false,
        ),
        TopMenuButton(
          tooltip: '设置',
          icon: Icons.settings_outlined,
          onPressed: _openSettings,
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(book.title),
        ),
        body: _buildReader(),
      ),
    );
  }
}

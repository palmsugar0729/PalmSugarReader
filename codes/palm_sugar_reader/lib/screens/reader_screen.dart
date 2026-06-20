import 'package:file_picker/file_picker.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../converters/format_converter.dart';
import '../models/book.dart';
import '../models/bookmark.dart';
import '../readers/image_reader.dart';
import '../readers/txt_reader.dart';
import '../readers/markdown_reader.dart';
import '../readers/epub_reader.dart';
import '../readers/pdf_reader.dart';
import '../main.dart';
import '../services/bookmark_storage.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../widgets/top_menu_bar.dart';
import 'settings_screen.dart';

/// 阅读器路由壳 — 根据文件格式分发到对应阅读器
///
/// 顶部菜单栏按钮：
/// - 标注工具
/// - 书签（PDF/EPUB）
/// - 格式转换（PopMenu 弹出可选目标格式）
/// - 背景色
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

  // ── 书签 ──
  List<Bookmark> _bookmarks = [];
  bool _bookmarksLoaded = false;

  @override
  void initState() {
    super.initState();
    if (book.format == BookFormat.pdf || book.format == BookFormat.epub) {
      _loadBookmarks();
    }
  }

  Future<void> _loadBookmarks() async {
    final list = await BookmarkStorage.loadForFile(book.filePath);
    _bookmarksLoaded = true;
    if (mounted) setState(() => _bookmarks = list);
  }

  bool get _isBookmarkable =>
      book.format == BookFormat.pdf || book.format == BookFormat.epub;

  // ── 当前页码（1-based）──
  int get _currentPageNumber {
    if (book.format == BookFormat.pdf) {
      return _pdfReaderKey.currentState?.currentPage ?? 1;
    } else if (book.format == BookFormat.epub) {
      return (_epubReaderKey.currentState?.currentGlobalPage ?? 0) + 1;
    }
    return 1;
  }

  int get _totalPages {
    if (book.format == BookFormat.pdf) {
      return _pdfReaderKey.currentState?.pageCount ?? 1;
    } else if (book.format == BookFormat.epub) {
      return _epubReaderKey.currentState?.totalPages ?? 1;
    }
    return 1;
  }

  double get _position {
    if (_totalPages <= 1) return 0.0;
    return ((_currentPageNumber - 1) / (_totalPages - 1)).clamp(0.0, 1.0);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 书签操作
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> _addBookmark() async {
    String? chapterTitle;
    int? chapterIndex;
    if (book.format == BookFormat.epub) {
      final epub = _epubReaderKey.currentState;
      if (epub != null) {
        chapterIndex = epub.currentChapterIndex;
        chapterTitle = epub.currentChapterTitle;
      }
    }

    final bookmark = Bookmark(
      id: BookmarkStorage.generateId(),
      filePath: book.filePath,
      pageNumber: _currentPageNumber,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      position: _position,
      format: book.format,
    );

    // 先更新内存（即时 UI 反馈，不依赖磁盘）
    _bookmarks = [..._bookmarks, bookmark];
    _bookmarks.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
    if (mounted) setState(() {});

    // 再异步写磁盘（跨会话持久化）
    try {
      await BookmarkStorage.add(bookmark);
    } catch (e) {
      debugPrint('📑 [ReaderScreen] 书签保存失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('书签保存失败: $e'),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _deleteBookmark(Bookmark bm) async {
    _bookmarks.removeWhere((b) => b.id == bm.id);
    if (mounted) setState(() {});
    try {
      await BookmarkStorage.remove(book.filePath, bm.id);
    } catch (e) {
      debugPrint('📑 [ReaderScreen] 书签删除失败: $e');
    }
  }

  void _jumpToBookmark(Bookmark bm) {
    Navigator.of(context).pop(); // close sheet
    if (book.format == BookFormat.pdf) {
      _pdfReaderKey.currentState?.jumpToPage(bm.pageNumber);
    } else if (book.format == BookFormat.epub) {
      // EPUB pageNumber 是 1-based，jumpToGlobalPage 是 0-based
      _epubReaderKey.currentState?.jumpToGlobalPage(bm.pageNumber - 1);
    }
  }

  Future<void> _showBookmarkSheet() async {
    if (!_bookmarksLoaded) await _loadBookmarks();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.3,
              maxChildSize: 0.85,
              expand: false,
              builder: (ctx, scrollController) {
                final list = _bookmarks;
                return Column(
                  children: [
                    // 拖拽把手
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // 标题栏
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.bookmark, color: AppTheme.primaryDark, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            '书签 (${list.length})',
                            style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: () async {
                              await _addBookmark();
                              if (ctx.mounted && mounted) {
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('已添加书签：第 $_currentPageNumber 页'),
                                    backgroundColor: AppTheme.primaryDark,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('添加当前页'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primaryDark,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              textStyle: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // 列表
                    Expanded(
                      child: list.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bookmark_border, size: 48,
                                      color: Colors.grey[400]),
                                  const SizedBox(height: 12),
                                  Text('暂无书签',
                                      style: TextStyle(color: Colors.grey[500])),
                                  const SizedBox(height: 4),
                                  Text('点击上方按钮添加当前页',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                                ],
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: list.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1, indent: 72),
                              itemBuilder: (ctx, i) {
                                final bm = list[i];
                                return _BookmarkTile(
                                  bookmark: bm,
                                  onTap: () => _jumpToBookmark(bm),
                                  onDelete: () async {
                                    await _deleteBookmark(bm);
                                    setSheetState(() {});
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 原有方法
  // ════════════════════════════════════════════════════════════════════════════

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
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final convertedBook = Book.fromFile(result.outputPath!);
                if (convertedBook.isReadable) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => ReaderScreen(book: convertedBook),
                    ),
                  );
                }
              });
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
              book.format == BookFormat.epub ||
              book.format == BookFormat.image,
          onPressed: _showAnnotHelp,
        ),
        TopMenuButton(
          tooltip: '书签',
          icon: Icons.bookmark,
          enabled: _isBookmarkable,
          onPressed: _showBookmarkSheet,
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
          actions: (Platform.isAndroid || Platform.isIOS) ? [
            if (book.format == BookFormat.pdf ||
                book.format == BookFormat.epub ||
                book.format == BookFormat.image)
              IconButton(
                tooltip: '标注工具',
                icon: const Icon(Icons.edit),
                onPressed: _showAnnotHelp,
              ),
            if (_isBookmarkable)
              IconButton(
                tooltip: '书签',
                icon: const Icon(Icons.bookmark),
                onPressed: _showBookmarkSheet,
              ),
            if (FormatConverter.getAvailableTargets(book.format).isNotEmpty)
              IconButton(
                key: _convertButtonKey,
                tooltip: '格式转换',
                icon: const Icon(Icons.transform),
                onPressed: _showConvertMenu,
              ),
            IconButton(
              tooltip: '背景色',
              icon: const Icon(Icons.brightness_6),
              onPressed: _cycleTheme,
            ),
            IconButton(
              tooltip: '设置',
              icon: const Icon(Icons.settings_outlined),
              onPressed: _openSettings,
            ),
          ] : null,
        ),
        body: _buildReader(),
      ),
    );
  }
}

// ── 书签列表项 ──

class _BookmarkTile extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BookmarkTile({
    required this.bookmark,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${bookmark.createdAt.year}-${bookmark.createdAt.month.toString().padLeft(2, '0')}-${bookmark.createdAt.day.toString().padLeft(2, '0')} '
        '${bookmark.createdAt.hour.toString().padLeft(2, '0')}:${bookmark.createdAt.minute.toString().padLeft(2, '0')}';

    return Slidable(
      key: ValueKey('bookmark_${bookmark.id}'),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.2,
        children: [
          CustomSlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            borderRadius: BorderRadius.circular(12),
            padding: EdgeInsets.zero,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete, size: 20),
                SizedBox(height: 2),
                Text('删除', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryLight.withAlpha(80),
          child: Text(
            '${bookmark.pageNumber}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryDark,
              fontSize: 14,
            ),
          ),
        ),
        title: Text(
          bookmark.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          timeStr,
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey[400]),
          onPressed: onDelete,
        ),
        onTap: onTap,
      ),
    );
  }
}

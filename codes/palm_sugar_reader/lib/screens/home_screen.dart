import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../models/book.dart';
import '../services/annotation_service.dart';
import '../services/bookmark_service.dart';
import '../theme.dart';
import '../utils/file_utils.dart';
import '../main.dart';
import '../services/settings_service.dart';
import '../converters/image_pdf_converter.dart';
import '../converters/format_converter.dart';
import '../widgets/top_menu_bar.dart';
import 'reader_screen.dart';
import 'settings_screen.dart';

/// 首页 — 最近文件列表 + 文件选择 + 批量删除 + 书签持久化
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Book> _recentBooks = [];
  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final bookmarks = await BookmarkService.loadBookmarks();
    if (bookmarks.isNotEmpty && mounted) {
      setState(() => _recentBooks.addAll(bookmarks));
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: FileUtils.supportedExtensions,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final book = Book.fromFile(path);
      if (book.isReadable) {
        // 先检测同目录批量导入（在打开书籍前弹窗，受设置开关控制）
        final settings = await SettingsService.load();
        if (settings.batchImport) {
          await _checkSiblingFiles(path);
        }
        await _addAndOpenBook(book);
      } else {
        _showUnsupportedDialog(book.title);
      }
    }
  }

  /// 扫描同目录下的相似文件，提示批量导入
  ///
  /// 匹配规则：同目录 + 同扩展名 + 文件名前缀匹配
  /// - 提取选中文件的"词干"（去掉尾部数字和分隔符）
  /// - 其他文件的词干前缀匹配才被纳入
  /// - 词干过短时（<2），退化为同扩展名匹配
  Future<void> _checkSiblingFiles(String pickedPath) async {
    try {
      final pickedFile = File(pickedPath);
      final dir = pickedFile.parent;
      if (!await dir.exists()) return;

      final pickedExt = FileUtils.getExtension(pickedPath);
      final pickedName = _fileName(pickedPath);
      final pickedStem = _extractStem(pickedName);

      final existingPaths = _recentBooks.map((b) => b.filePath).toSet();
      final siblings = <String>[];

      await for (final entity in dir.list()) {
        if (entity is File) {
          final absPath = entity.absolute.path;
          // 跳过自身和已添加的文件
          if (absPath == pickedPath || existingPaths.contains(absPath)) {
            continue;
          }
          // 必须同扩展名
          if (FileUtils.getExtension(absPath) != pickedExt) continue;

          // 前缀匹配
          final candidateName = _fileName(absPath);
          final candidateStem = _extractStem(candidateName);

          if (pickedStem.length >= 2 &&
              candidateStem.length >= 2 &&
              (candidateStem == pickedStem ||
                  candidateStem.startsWith(pickedStem) ||
                  pickedStem.startsWith(candidateStem))) {
            siblings.add(absPath);
          } else if (pickedStem.length < 2 || candidateStem.length < 2) {
            // 词干太短，退化为同扩展名匹配
            siblings.add(absPath);
          }
        }
      }

      if (siblings.isEmpty || !mounted) return;

      // 弹窗询问是否批量导入
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('批量导入'),
          content: Text(
            '检测到同目录下还有 ${siblings.length} 个可读文件，是否一并导入？\n\n'
            '${siblings.take(5).map((p) => '· ${p.split(Platform.pathSeparator).last}').join('\n')}'
            '${siblings.length > 5 ? '\n· ...还有 ${siblings.length - 5} 个' : ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('暂不'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('全部导入'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        int imported = 0;
        final saveFutures = <Future<void>>[];
        for (final siblingPath in siblings) {
          final siblingBook = Book.fromFile(siblingPath);
          if (siblingBook.isReadable) {
            _recentBooks.removeWhere((b) => b.filePath == siblingBook.filePath);
            _recentBooks.insert(0, siblingBook);
            saveFutures.add(BookmarkService.addOrUpdate(siblingBook));
            imported++;
          }
        }
        await Future.wait(saveFutures);
        if (imported > 0 && mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已导入 $imported 个文件')),
          );
        }
      }
    } catch (_) {
      // 静默失败，不影响正常阅读流程
    }
  }

  /// 将书籍添加到列表并打开
  Future<void> _addAndOpenBook(Book book) async {
    setState(() {
      _recentBooks.removeWhere((b) => b.filePath == book.filePath);
      _recentBooks.insert(0, book);
    });
    await BookmarkService.addOrUpdate(book);
    _openBook(book);
  }

  Future<void> _openBook(Book book) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
    );
    // 返回后刷新列表（可能有进度更新）
    _refreshBookmarks();
  }

  Future<void> _refreshBookmarks() async {
    final bookmarks = await BookmarkService.loadBookmarks();
    if (!mounted) return;
    setState(() {
      // 合并书签进度到当前列表
      for (final bm in bookmarks) {
        final idx = _recentBooks.indexWhere((b) => b.filePath == bm.filePath);
        if (idx >= 0) {
          _recentBooks[idx].lastPosition = bm.lastPosition;
          _recentBooks[idx].lastReadAt = bm.lastReadAt;
        }
      }
    });
  }

  void _showUnsupportedDialog(String fileName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('不支持的格式'),
        content: Text('文件 "$fileName" 暂不支持阅读。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedIndices.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIndices.clear();
    });
  }

  void _toggleSelect(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIndices.addAll(Iterable.generate(_recentBooks.length));
    });
  }

  void _deleteSelected() {
    if (_selectedIndices.isEmpty) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 ${_selectedIndices.length} 个文件记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                final sorted = _selectedIndices.toList()
                  ..sort((a, b) => b.compareTo(a));
                for (final i in sorted) {
                  final book = _recentBooks[i];
                  BookmarkService.remove(book.filePath);
                  AnnotationService.clearForFile(book.filePath);
                  _recentBooks.removeAt(i);
                }
                _selectedIndices.clear();
                _isSelectionMode = false;
              });
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 将选中的图片批量转为 PDF
  Future<void> _convertSelectedToPdf() async {
    if (_selectedIndices.isEmpty) return;

    final selectedBooks = _selectedIndices.map((i) => _recentBooks[i]).toList();
    final imageBooks = selectedBooks.where((b) => b.format == BookFormat.image).toList();

    if (imageBooks.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择图片文件')),
      );
      return;
    }

    // 选择排版模式
    final mode = await showDialog<ImagePdfMode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PDF 排版模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.view_agenda),
              title: const Text('一图一页'),
              subtitle: const Text('每张图片单独一页'),
              onTap: () => Navigator.pop(ctx, ImagePdfMode.onePerPage),
            ),
            ListTile(
              leading: const Icon(Icons.grid_view),
              title: const Text('紧凑排列'),
              subtitle: const Text('每页 2×2 网格排列'),
              onTap: () => Navigator.pop(ctx, ImagePdfMode.compact),
            ),
          ],
        ),
      ),
    );

    if (mode == null || !mounted) return;

    // 选择输出路径
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: '保存 PDF 文件',
      fileName: 'merged.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (outputPath == null || !mounted) return;

    // 显示加载
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // 执行转换
    final result = await ImagePdfConverter.convertMultiple(
      imageBooks.map((b) => b.filePath).toList(),
      outputPath,
      mode: mode,
    );

    // 关闭加载
    if (!mounted) return;
    Navigator.of(context).pop();

    if (!mounted) return;
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PDF 转换成功'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: '打开',
            onPressed: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final book = Book.fromFile(result.outputPath!);
                if (book.isReadable) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
                  );
                }
              });
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? '转换失败')),
      );
    }

    _exitSelectionMode();
  }

  void _removeSingle(int index) {
    final book = _recentBooks[index];
    BookmarkService.remove(book.filePath);
    AnnotationService.clearForFile(book.filePath);
    setState(() => _recentBooks.removeAt(index));
  }

  /// 右键上下文菜单
  void _showContextMenu(BuildContext context, Book book, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'rename',
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, size: 16),
              const SizedBox(width: 8),
              const Text('重命名', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'delete',
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: const Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text('删除', style: TextStyle(fontSize: 13, color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null || !mounted) return;
      switch (value) {
        case 'rename':
          _renameBook(book);
          break;
        case 'delete':
          _deleteSingle(book);
          break;
      }
    });
  }

  /// 重命名文件
  Future<void> _renameBook(Book book) async {
    final controller = TextEditingController(text: book.title);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名文件'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: '新文件名（不含扩展名）',
            hintText: book.title,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(ctx, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == book.title) return;

    try {
      final oldFile = File(book.filePath);
      final ext = book.filePath.split('.').last;
      final dir = oldFile.parent;
      final newPath = '${dir.path}${Platform.pathSeparator}$newName.$ext';
      await oldFile.rename(newPath);

      // 更新 book 记录
      if (!mounted) return;
      setState(() {
        final idx = _recentBooks.indexWhere((b) => b.id == book.id);
        if (idx >= 0) {
          final updated = Book.fromFile(newPath);
          updated.lastReadAt = book.lastReadAt;
          updated.lastPosition = book.lastPosition;
          _recentBooks[idx] = updated;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已重命名为 "$newName.$ext"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('重命名失败: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  /// 删除单个文件记录
  void _deleteSingle(Book book) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('将 "${book.title}" 从列表中移除？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final idx = _recentBooks.indexWhere((b) => b.id == book.id);
              if (idx >= 0) {
                BookmarkService.remove(book.filePath);
                AnnotationService.clearForFile(book.filePath);
                setState(() => _recentBooks.removeAt(idx));
              }
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

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

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  /// 处理外部文件拖入
  Future<void> _handleDrop(DropDoneDetails detail) async {
    if (detail.files.isEmpty) return;

    for (final file in detail.files) {
      final path = file.path;

      final book = Book.fromFile(path);
      if (book.isReadable) {
        await _addAndOpenBook(book);
        return;
      }
    }

    if (mounted) {
      _showUnsupportedDialog('拖入的文件');
    }
  }

  @override
  Widget build(BuildContext context) {
    return TopMenuOverlay(
      buttons: [
        TopMenuButton(
          tooltip: '批量选择',
          icon: Icons.checklist,
          enabled: _recentBooks.isNotEmpty && !_isSelectionMode,
          onPressed: _toggleSelectionMode,
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
        appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
        body: DropTarget(
          onDragDone: (detail) => _handleDrop(detail),
          child: _recentBooks.isEmpty ? _buildEmptyState() : _buildBookList(),
        ),
        floatingActionButton: _isSelectionMode
            ? null
            : FloatingActionButton.extended(
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('打开文件'),
              ),
        bottomNavigationBar: _isSelectionMode ? _buildBottomActionBar() : null,
      ),
    );
  }

  AppBar _buildNormalAppBar() {
    return AppBar(
      title: const Text('PalmSugarReader'),
      automaticallyImplyLeading: false,
    );
  }

  AppBar _buildSelectionAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _exitSelectionMode,
      ),
      title: Text('已选择 ${_selectedIndices.length} 项'),
      actions: [
        TextButton(
          onPressed: _selectAll,
          child: const Text('全选', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(26),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _selectedIndices.isEmpty ? null : _deleteSelected,
                icon: const Icon(Icons.delete_outline),
                label: const Text('删除'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _selectedIndices.isEmpty ? null : _convertSelectedToPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('转PDF'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryDark,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 80,
            color: AppTheme.primaryLight,
          ),
          const SizedBox(height: 24),
          Text(
            '还没有打开过文件',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角按钮，开始阅读吧',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildFormatChip('PDF'),
              _buildFormatChip('EPUB'),
              _buildFormatChip('TXT'),
              _buildFormatChip('Markdown'),
              _buildFormatChip('图片'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormatChip(String label) {
    return Chip(
      label: Text(label),
      backgroundColor: AppTheme.primaryLight.withAlpha(77),
      labelStyle: TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 12,
      ),
      side: BorderSide.none,
    );
  }

  Widget _buildBookList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recentBooks.length,
      itemBuilder: (context, index) {
        final book = _recentBooks[index];
        final isSelected = _selectedIndices.contains(index);

        if (_isSelectionMode) {
          return Card(
            child: ListTile(
              leading: Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSelect(index),
                activeColor: AppTheme.primaryDark,
              ),
              title: Text(book.title),
              subtitle: Text(book.format.displayName),
              onTap: () => _toggleSelect(index),
            ),
          );
        }

        return Dismissible(
          key: ValueKey(book.id),
          direction: DismissDirection.endToStart,
          dismissThresholds: const {DismissDirection.endToStart: 0.25},
          movementDuration: const Duration(milliseconds: 200),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => _removeSingle(index),
          confirmDismiss: (_) async {
            return await showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('确认移除'),
                content: Text('将 "${book.title}" 从列表中移除？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('移除', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
          child: GestureDetector(
            onSecondaryTapUp: (details) =>
                _showContextMenu(context, book, details.globalPosition),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryLight.withAlpha(128),
                  child: Icon(
                    _getIconForFormat(book.format),
                    color: AppTheme.primaryDark,
                  ),
                ),
                title: Text(book.title),
                subtitle: Text(book.lastReadAt != null
                    ? '${book.format.displayName} · 上次: ${_formatDate(book.lastReadAt!)}'
                    : book.format.displayName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openBook(book),
                onLongPress: _toggleSelectionMode,
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getIconForFormat(BookFormat format) {
    return switch (format) {
      BookFormat.pdf => Icons.picture_as_pdf,
      BookFormat.epub => Icons.menu_book,
      BookFormat.txt => Icons.description,
      BookFormat.markdown => Icons.code,
      BookFormat.image => Icons.image,
      BookFormat.unknown => Icons.insert_drive_file,
    };
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// 提取文件名（不含扩展名）
  static String _fileName(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  /// 提取文件名"词干"——去掉尾部数字和分隔符
  ///
  /// 例：chapter3 → chapter, vol01 → vol, 第3章 → 第, readme → readme
  static String _extractStem(String name) {
    // 去掉尾部数字及前面的分隔符（- _ . 空格）
    final trimmed = name.replaceAll(RegExp(r'[\d\-_.\s]+$'), '');
    return trimmed.isEmpty ? name : trimmed;
  }
}

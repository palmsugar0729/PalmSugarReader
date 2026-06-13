import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/book.dart';
import '../services/bookmark_service.dart';
import '../theme.dart';
import '../utils/file_utils.dart';
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
      final book = Book.fromFile(result.files.single.path!);
      if (book.isReadable) {
        setState(() {
          _recentBooks.removeWhere((b) => b.filePath == book.filePath);
          _recentBooks.insert(0, book);
        });
        // 持久化：仅对 PDF/EPUB 保存书签
        if (book.isBookmarkable) {
          BookmarkService.addOrUpdate(book);
        }
        _openBook(book);
      } else {
        _showUnsupportedDialog(book.title);
      }
    }
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
                  if (book.isBookmarkable) {
                    BookmarkService.remove(book.filePath);
                  }
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

  void _removeSingle(int index) {
    final book = _recentBooks[index];
    if (book.isBookmarkable) {
      BookmarkService.remove(book.filePath);
    }
    setState(() => _recentBooks.removeAt(index));
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
      body: _recentBooks.isEmpty ? _buildEmptyState() : _buildBookList(),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('打开文件'),
            ),
      bottomNavigationBar: _isSelectionMode ? _buildBottomActionBar() : null,
    );
  }

  AppBar _buildNormalAppBar() {
    return AppBar(
      title: const Text('PalmSugarReader'),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: '设置',
          onPressed: _openSettings,
        ),
        if (_recentBooks.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.checklist),
            tooltip: '批量选择',
            onPressed: _toggleSelectionMode,
          ),
      ],
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
}

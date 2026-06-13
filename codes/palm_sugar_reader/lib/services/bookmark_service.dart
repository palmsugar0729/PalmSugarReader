import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/book.dart';

/// 书签/最近文件持久化服务
///
/// 使用 JSON 文件存储最近打开的电子书（EPUB/PDF）及其阅读进度。
/// 文件位于应用数据目录下的 `bookmarks.json`。
class BookmarkService {
  BookmarkService._();

  static Future<File> get _bookmarkFile async {
    final dir = await getApplicationSupportDirectory();
    // 确保目录存在
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, 'bookmarks.json'));
  }

  /// 加载所有书签
  static Future<List<Book>> loadBookmarks() async {
    try {
      final file = await _bookmarkFile;
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      final list = json.decode(content) as List<dynamic>;
      return list
          .map((e) => Book.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 保存所有书签
  static Future<void> saveBookmarks(List<Book> books) async {
    try {
      final file = await _bookmarkFile;
      final list = books.map((b) => b.toJson()).toList();
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(list),
        encoding: utf8,
      );
    } catch (_) {
      // 静默失败，不影响阅读体验
    }
  }

  /// 添加或更新一个书签（按 filePath 去重）
  static Future<void> addOrUpdate(Book book) async {
    final books = await loadBookmarks();
    books.removeWhere((b) => b.filePath == book.filePath);
    books.insert(0, book);
    await saveBookmarks(books);
  }

  /// 移除一个书签
  static Future<void> remove(String filePath) async {
    final books = await loadBookmarks();
    books.removeWhere((b) => b.filePath == filePath);
    await saveBookmarks(books);
  }

  /// 更新阅读进度
  static Future<void> updateProgress(
    String filePath,
    double position,
  ) async {
    final books = await loadBookmarks();
    final index = books.indexWhere((b) => b.filePath == filePath);
    if (index >= 0) {
      books[index].lastPosition = position;
      books[index].lastReadAt = DateTime.now();
      // 最近阅读的放最前面
      final book = books.removeAt(index);
      books.insert(0, book);
      await saveBookmarks(books);
    }
  }
}

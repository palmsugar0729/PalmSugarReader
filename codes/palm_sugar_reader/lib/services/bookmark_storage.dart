import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/bookmark.dart';

/// 书签持久化服务 — 每个文件独立 JSON
///
/// 存储位置：`{appData}/bookmarks/bm_{hash}.json`
/// 与 [BookmarkService]（最近文件）区分：这是用户手动创建的书签
class BookmarkStorage {
  BookmarkStorage._();

  static String _hashPath(String path) {
    return path.hashCode.abs().toRadixString(36).padLeft(12, '0');
  }

  static Future<File> _bookmarkFile(String filePath) async {
    final dir = await getApplicationSupportDirectory();
    final bookmarksDir = Directory(p.join(dir.path, 'bookmarks'));
    if (!await bookmarksDir.exists()) {
      await bookmarksDir.create(recursive: true);
    }
    return File(p.join(bookmarksDir.path, 'bm_${_hashPath(filePath)}.json'));
  }

  /// 加载某文件的所有书签（按页码排序）
  static Future<List<Bookmark>> loadForFile(String filePath) async {
    try {
      final file = await _bookmarkFile(filePath);
      if (!await file.exists()) {
        debugPrint('📑 [BookmarkStorage] 文件不存在: ${file.path}');
        return [];
      }
      final content = await file.readAsString();
      final list = json.decode(content) as List<dynamic>;
      final bookmarks = list
          .map((e) => Bookmark.fromJson(e as Map<String, dynamic>))
          .toList();
      bookmarks.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
      debugPrint('📑 [BookmarkStorage] 加载 ${bookmarks.length} 个书签');
      return bookmarks;
    } catch (e) {
      debugPrint('📑 [BookmarkStorage] 加载失败: $e');
      return [];
    }
  }

  /// 保存书签列表（异常直接上抛，由调用方处理）
  static Future<void> _saveForFile(
      String filePath, List<Bookmark> bookmarks) async {
    final file = await _bookmarkFile(filePath);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(
      bookmarks.map((b) => b.toJson()).toList(),
    );
    await file.writeAsString(jsonStr, encoding: utf8);
    debugPrint('📑 [BookmarkStorage] 已保存 ${bookmarks.length} 个书签到 ${file.path}');
  }

  /// 添加书签
  static Future<void> add(Bookmark bookmark) async {
    final list = await loadForFile(bookmark.filePath);
    list.add(bookmark);
    list.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
    await _saveForFile(bookmark.filePath, list);
  }

  /// 删除书签
  static Future<void> remove(String filePath, String bookmarkId) async {
    final list = await loadForFile(filePath);
    list.removeWhere((b) => b.id == bookmarkId);
    await _saveForFile(filePath, list);
  }

  /// 清除某文件的所有书签
  static Future<void> clearForFile(String filePath) async {
    try {
      final file = await _bookmarkFile(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// 生成唯一 ID
  static String generateId() {
    final rand = Random();
    final chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(16, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}

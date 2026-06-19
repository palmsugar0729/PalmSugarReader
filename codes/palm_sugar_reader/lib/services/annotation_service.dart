import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/annotation.dart';

/// 标注持久化服务 — 每个文件独立 JSON
///
/// 付费开关：`AnnotationService.enabled` 默认 true，设为 false 后标注功能不可用
class AnnotationService {
  AnnotationService._();

  /// 付费开关（后期只需改这里即可全局禁用标注）
  static bool enabled = true;

  static String _hashPath(String path) {
    return path.hashCode.abs().toRadixString(36).padLeft(12, '0');
  }

  static Future<File> _annotationFile(String filePath) async {
    final dir = await getApplicationSupportDirectory();
    final annotationsDir = Directory(p.join(dir.path, 'annotations'));
    if (!await annotationsDir.exists()) {
      await annotationsDir.create(recursive: true);
    }
    return File(p.join(annotationsDir.path, 'ann_${_hashPath(filePath)}.json'));
  }

  /// 加载某文件的所有标注
  static Future<List<Annotation>> loadForFile(String filePath) async {
    try {
      final file = await _annotationFile(filePath);
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final list = json.decode(content) as List<dynamic>;
      return list
          .map((e) => Annotation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 保存标注列表
  static Future<void> _saveForFile(
      String filePath, List<Annotation> annotations) async {
    try {
      final file = await _annotationFile(filePath);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(
          annotations.map((a) => a.toJson()).toList(),
        ),
        encoding: utf8,
      );
    } catch (_) {}
  }

  /// 添加标注
  static Future<void> add(Annotation annotation) async {
    final list = await loadForFile(annotation.filePath);
    list.add(annotation);
    await _saveForFile(annotation.filePath, list);
  }

  /// 删除标注
  static Future<void> remove(String filePath, String annotationId) async {
    final list = await loadForFile(filePath);
    list.removeWhere((a) => a.id == annotationId);
    await _saveForFile(filePath, list);
  }

  /// 清除某文件的所有标注
  static Future<void> clearForFile(String filePath) async {
    try {
      final file = await _annotationFile(filePath);
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

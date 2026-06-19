import '../models/book.dart';

/// 用户手动创建的书签 — 记录文件中的特定位置
class Bookmark {
  final String id;
  final String filePath;
  final String? label; // 用户自定义名称，默认用页码
  final int pageNumber; // 1-based 页码
  final int? chapterIndex; // EPUB 章节索引
  final String? chapterTitle; // EPUB 章节标题
  final double position; // 归一化位置 0~1
  final BookFormat format;
  final DateTime createdAt;

  Bookmark({
    required this.id,
    required this.filePath,
    this.label,
    required this.pageNumber,
    this.chapterIndex,
    this.chapterTitle,
    required this.position,
    required this.format,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 显示用标题：label > 第N页 > 位置百分比
  String get displayTitle {
    if (label != null && label!.trim().isNotEmpty) return label!;
    if (chapterTitle != null && chapterTitle!.isNotEmpty) {
      return '$chapterTitle · 第$pageNumber页';
    }
    return '第 $pageNumber 页';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'filePath': filePath,
        if (label != null && label!.isNotEmpty) 'label': label,
        'pageNumber': pageNumber,
        if (chapterIndex != null) 'chapterIndex': chapterIndex,
        if (chapterTitle != null) 'chapterTitle': chapterTitle,
        'position': position,
        'format': format.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      label: json['label'] as String?,
      pageNumber: json['pageNumber'] as int,
      chapterIndex: json['chapterIndex'] as int?,
      chapterTitle: json['chapterTitle'] as String?,
      position: (json['position'] as num).toDouble(),
      format: BookFormat.values.firstWhere(
        (f) => f.name == json['format'],
        orElse: () => BookFormat.unknown,
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

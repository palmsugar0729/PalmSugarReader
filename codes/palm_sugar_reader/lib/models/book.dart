import 'dart:io';

/// 支持的文件格式
enum BookFormat {
  pdf,
  epub,
  txt,
  markdown,
  image,
  unknown;

  String get displayName {
    return switch (this) {
      BookFormat.pdf => 'PDF',
      BookFormat.epub => 'EPUB',
      BookFormat.txt => 'TXT',
      BookFormat.markdown => 'Markdown',
      BookFormat.image => '图片',
      BookFormat.unknown => '未知',
    };
  }

  String get iconName {
    return switch (this) {
      BookFormat.pdf => 'picture_as_pdf',
      BookFormat.epub => 'menu_book',
      BookFormat.txt => 'description',
      BookFormat.markdown => 'code',
      BookFormat.image => 'image',
      BookFormat.unknown => 'insert_drive_file',
    };
  }
}

/// 书籍/文件模型
class Book {
  final String id;
  final String title;
  final String filePath;
  final BookFormat format;
  final DateTime addedAt;
  DateTime? lastReadAt;
  double? lastPosition; // 0.0 ~ 1.0 或页码，视格式而定

  Book({
    required this.id,
    required this.title,
    required this.filePath,
    required this.format,
    required this.addedAt,
    this.lastReadAt,
    this.lastPosition,
  });

  /// 从文件路径创建 Book
  factory Book.fromFile(String filePath) {
    final file = File(filePath);
    final fileName = file.path.split(Platform.pathSeparator).last;
    final nameWithoutExt = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;

    return Book(
      id: '${filePath}_${file.statSync().modified.millisecondsSinceEpoch}',
      title: nameWithoutExt,
      filePath: filePath,
      format: _detectFormat(fileName),
      addedAt: DateTime.now(),
    );
  }

  static BookFormat _detectFormat(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    return switch (ext) {
      'pdf' => BookFormat.pdf,
      'epub' => BookFormat.epub,
      'txt' => BookFormat.txt,
      'md' || 'markdown' => BookFormat.markdown,
      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' || 'bmp' => BookFormat.image,
      _ => BookFormat.unknown,
    };
  }

  bool get isReadable =>
      format != BookFormat.unknown;
}

import '../models/book.dart';

/// 文件工具类
class FileUtils {
  FileUtils._();

  /// 根据文件扩展名判断格式
  static BookFormat detectFormat(String fileName) {
    final ext = fileName.toLowerCase().split('.').lastOrNull ?? '';
    return switch (ext) {
      'pdf' => BookFormat.pdf,
      'epub' => BookFormat.epub,
      'txt' => BookFormat.txt,
      'md' || 'markdown' => BookFormat.markdown,
      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' || 'bmp' || 'tiff' =>
        BookFormat.image,
      _ => BookFormat.unknown,
    };
  }

  /// 获取文件扩展名
  static String getExtension(String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    return lastDot >= 0 ? fileName.substring(lastDot + 1).toLowerCase() : '';
  }

  /// 支持的文件过滤器（用于 file_picker）
  static List<String> get supportedExtensions => [
    'pdf',
    'epub',
    'txt',
    'md',
    'markdown',
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
  ];
}

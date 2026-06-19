import '../models/book.dart';
import 'txt_md_converter.dart';
import 'epub_md_converter.dart';
import 'md_pdf_converter.dart';
import 'image_pdf_converter.dart';
import 'md_epub_converter.dart';

/// 转换结果
class ConvertResult {
  final bool success;
  final String? outputPath;
  final String? errorMessage;

  const ConvertResult({
    required this.success,
    this.outputPath,
    this.errorMessage,
  });

  factory ConvertResult.ok(String path) =>
      ConvertResult(success: true, outputPath: path);

  factory ConvertResult.fail(String error) =>
      ConvertResult(success: false, errorMessage: error);
}

/// 格式转换协调器 — 以 Markdown 为核心中转格式
///
/// 直接转换（MVP 支持）：
/// - TXT → MD, MD → TXT
/// - EPUB → MD
/// - MD → PDF
///
/// 链式转换（通过 MD 中转）：
/// - EPUB → MD → PDF 等
class FormatConverter {
  FormatConverter._();

  /// 获取源格式可转换的目标格式列表
  static List<BookFormat> getAvailableTargets(BookFormat source) {
    return switch (source) {
      BookFormat.txt => [BookFormat.markdown],
      BookFormat.markdown => [BookFormat.txt, BookFormat.pdf, BookFormat.epub],
      BookFormat.epub => [BookFormat.markdown],
      BookFormat.image => [BookFormat.pdf],
      _ => [],
    };
  }

  /// 获取目标格式的显示名称和扩展名
  static String targetExtension(BookFormat target) {
    return switch (target) {
      BookFormat.markdown => 'md',
      BookFormat.txt => 'txt',
      BookFormat.pdf => 'pdf',
      BookFormat.epub => 'epub',
      _ => '',
    };
  }

  /// 执行格式转换
  ///
  /// [sourcePath] 源文件路径
  /// [source] 源格式
  /// [target] 目标格式
  /// [outputPath] 输出文件路径（可选，不指定则自动生成）
  static Future<ConvertResult> convert({
    required String sourcePath,
    required BookFormat source,
    required BookFormat target,
    String? outputPath,
  }) async {
    try {
      // 直接转换
      final directResult = await _convertDirect(
        sourcePath: sourcePath,
        source: source,
        target: target,
        outputPath: outputPath,
      );
      if (directResult != null) return directResult;

      // 链式转换（通过 MD 中转）
      return await _convertViaMarkdown(
        sourcePath: sourcePath,
        source: source,
        target: target,
        outputPath: outputPath,
      );
    } catch (e) {
      return ConvertResult.fail('转换失败: $e');
    }
  }

  /// 直接转换（源 → 目标）
  static Future<ConvertResult?> _convertDirect({
    required String sourcePath,
    required BookFormat source,
    required BookFormat target,
    String? outputPath,
  }) async {
    final outPath = outputPath ??
        _defaultOutputPath(sourcePath, targetExtension(target));

    // TXT → MD
    if (source == BookFormat.txt && target == BookFormat.markdown) {
      return TxtMdConverter.toMarkdown(sourcePath, outPath);
    }

    // MD → TXT
    if (source == BookFormat.markdown && target == BookFormat.txt) {
      return TxtMdConverter.toText(sourcePath, outPath);
    }

    // EPUB → MD
    if (source == BookFormat.epub && target == BookFormat.markdown) {
      return EpubMdConverter.convert(sourcePath, outPath);
    }

    // MD → PDF
    if (source == BookFormat.markdown && target == BookFormat.pdf) {
      return MdPdfConverter.convert(sourcePath, outPath);
    }

    // MD → EPUB
    if (source == BookFormat.markdown && target == BookFormat.epub) {
      return MdEpubConverter.convert(sourcePath, outPath);
    }

    // 图片 → PDF（单图）
    if (source == BookFormat.image && target == BookFormat.pdf) {
      return ImagePdfConverter.convertSingle(sourcePath, outPath);
    }

    return null; // 无直接转换，尝试链式
  }

  /// 链式转换：源 → MD → 目标
  static Future<ConvertResult> _convertViaMarkdown({
    required String sourcePath,
    required BookFormat source,
    required BookFormat target,
    String? outputPath,
  }) async {
    // Step 1: 源 → MD（使用临时文件）
    final mdPath = outputPath != null
        ? '$outputPath.tmp.md'
        : _defaultOutputPath(sourcePath, 'md');

    final toMdResult = await _convertDirect(
      sourcePath: sourcePath,
      source: source,
      target: BookFormat.markdown,
      outputPath: mdPath,
    );

    if (toMdResult == null || !toMdResult.success) {
      return ConvertResult.fail(
        '链式转换第一步失败: ${toMdResult?.errorMessage ?? "无法转换为 Markdown"}',
      );
    }

    // Step 2: MD → 目标
    final finalPath = outputPath ??
        _defaultOutputPath(sourcePath, targetExtension(target));

    final finalResult = await _convertDirect(
      sourcePath: toMdResult.outputPath!,
      source: BookFormat.markdown,
      target: target,
      outputPath: finalPath,
    );

    return finalResult ??
        ConvertResult.fail('链式转换第二步失败: 不支持的转换');
  }

  /// 生成默认输出路径（同目录、同文件名、不同扩展名）
  static String _defaultOutputPath(String sourcePath, String newExt) {
    final lastDot = sourcePath.lastIndexOf('.');
    final basePath =
        lastDot >= 0 ? sourcePath.substring(0, lastDot) : sourcePath;
    return '$basePath.$newExt';
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:markdown/markdown.dart' as md;

import '../utils/encoding_utils.dart';
import 'format_converter.dart';

/// TXT ↔ Markdown 转换器
class TxtMdConverter {
  TxtMdConverter._();

  /// TXT → Markdown
  ///
  /// 读取 TXT 文件（自动多编码检测），写入 Markdown 文件。
  /// 可选添加 YAML frontmatter 元数据。
  static Future<ConvertResult> toMarkdown(
    String sourcePath,
    String outputPath,
  ) async {
    try {
      final file = File(sourcePath);
      if (!await file.exists()) {
        return ConvertResult.fail('源文件不存在: $sourcePath');
      }

      final bytes = await file.readAsBytes();
      final result = await EncodingUtils.detect(bytes);

      // 生成 Markdown 内容（添加元数据 frontmatter）
      final fileName = sourcePath.split(Platform.pathSeparator).last;
      final nameWithoutExt = fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;

      final buffer = StringBuffer();
      buffer.writeln('---');
      buffer.writeln('title: "$nameWithoutExt"');
      buffer.writeln('source_format: "txt"');
      buffer.writeln('original_encoding: "${result.encoding}"');
      buffer.writeln('converted_at: "${DateTime.now().toIso8601String()}"');
      buffer.writeln('---');
      buffer.writeln();
      buffer.writeln('# $nameWithoutExt');
      buffer.writeln();
      buffer.write(result.text);

      final outFile = File(outputPath);
      await outFile.writeAsString(buffer.toString(), encoding: utf8);

      return ConvertResult.ok(outputPath);
    } catch (e) {
      return ConvertResult.fail('TXT → MD 转换失败: $e');
    }
  }

  /// Markdown → TXT
  ///
  /// 解析 Markdown AST，提取纯文本内容，写入 TXT 文件。
  static Future<ConvertResult> toText(
    String sourcePath,
    String outputPath,
  ) async {
    try {
      final file = File(sourcePath);
      if (!await file.exists()) {
        return ConvertResult.fail('源文件不存在: $sourcePath');
      }

      final mdContent = await file.readAsString();
      final textContent = _extractPlainText(mdContent);

      final outFile = File(outputPath);
      await outFile.writeAsString(textContent, encoding: utf8);

      return ConvertResult.ok(outputPath);
    } catch (e) {
      return ConvertResult.fail('MD → TXT 转换失败: $e');
    }
  }

  /// 从 Markdown 提取纯文本
  ///
  /// 使用 markdown 包解析为 AST，遍历节点提取文本。
  static String _extractPlainText(String markdown) {
    try {
      final document = md.Document().parse(markdown);
      final buffer = StringBuffer();

      void visit(md.Node node) {
        if (node is md.Text) {
          buffer.write(node.text);
        } else if (node is md.Element) {
          // 块级元素前后加换行
          if (_isBlockElement(node.tag)) {
            if (buffer.isNotEmpty &&
                !buffer.toString().endsWith('\n\n')) {
              buffer.writeln();
            }
          }
          // 遍历子节点
          if (node.children != null) {
            for (final child in node.children!) {
              visit(child);
            }
          }
          // 块级元素后加换行
          if (_isBlockElement(node.tag)) {
            if (!buffer.toString().endsWith('\n')) {
              buffer.writeln();
            }
          }
        }
        // HTML 块和代码块的处理：跳过标签，保留文本
      }

      for (final node in document) {
        visit(node);
      }
      return buffer.toString().trim();
    } catch (_) {
      // 降级处理：简单正则剥离
      return _stripMarkdownSimple(markdown);
    }
  }

  /// 简单正则剥离 Markdown 格式（降级方案）
  static String _stripMarkdownSimple(String markdown) {
    var text = markdown;
    // 移除 YAML frontmatter
    text = text.replaceAll(RegExp(r'^---\n.*?\n---\n', dotAll: true), '');
    // 移除标题标记
    text = text.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    // 移除粗体/斜体
    text = text.replaceAll(RegExp(r'\*{1,3}([^*]+)\*{1,3}'), r'$1');
    text = text.replaceAll(RegExp(r'_{1,3}([^_]+)_{1,3}'), r'$1');
    // 移除链接 [text](url)
    text = text.replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1');
    // 移除图片 ![alt](url)
    text = text.replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]*\)'), r'$1');
    // 移除行内代码
    text = text.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
    // 移除代码块
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    // 移除引用前缀
    text = text.replaceAll(RegExp(r'^>\s?', multiLine: true), '');
    // 移除列表标记
    text = text.replaceAll(RegExp(r'^[\s]*[-*+]\s', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^[\s]*\d+\.\s', multiLine: true), '');
    // 移除水平线
    text = text.replaceAll(RegExp(r'^[-*_]{3,}\s*$', multiLine: true), '');
    // 移除多余空行
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  static bool _isBlockElement(String tag) {
    return [
      'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
      'p', 'pre', 'blockquote', 'ul', 'ol', 'li',
      'hr', 'table', 'thead', 'tbody', 'tr',
    ].contains(tag);
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

import 'format_converter.dart';

/// EPUB → Markdown 转换器
///
/// 使用 epubx 解析 EPUB，提取章节的 HTML 内容，
/// 转换为 Markdown 格式输出。
class EpubMdConverter {
  EpubMdConverter._();

  /// EPUB → Markdown
  ///
  /// 读取 EPUB 文件，提取元数据和所有章节内容，
  /// 写入结构化的 Markdown 文件。
  static Future<ConvertResult> convert(
    String sourcePath,
    String outputPath,
  ) async {
    try {
      final file = File(sourcePath);
      if (!await file.exists()) {
        return ConvertResult.fail('源文件不存在: $sourcePath');
      }

      final bytes = await file.readAsBytes();

      // 使用 epubx 读取 EPUB 全部内容
      final epubBook = await EpubReader.readBook(bytes);

      final buffer = StringBuffer();

      // YAML frontmatter
      final title = epubBook.Title ?? 'Untitled';
      final author = epubBook.Author ?? 'Unknown';

      buffer.writeln('---');
      buffer.writeln('title: "$title"');
      buffer.writeln('author: "$author"');
      buffer.writeln('source_format: "epub"');
      buffer.writeln('converted_at: "${DateTime.now().toIso8601String()}"');
      buffer.writeln('---');
      buffer.writeln();
      buffer.writeln('# $title');
      if (epubBook.Author != null) {
        buffer.writeln();
        buffer.writeln('*作者: $author*');
      }
      buffer.writeln();

      // 遍历章节
      final chapters = epubBook.Chapters;
      if (chapters != null && chapters.isNotEmpty) {
        for (final chapter in chapters) {
          _writeChapter(buffer, chapter, 2);
        }
      } else {
        buffer.writeln('*(此 EPUB 无章节内容)*');
      }

      final outFile = File(outputPath);
      await outFile.writeAsString(buffer.toString(), encoding: utf8);

      return ConvertResult.ok(outputPath);
    } catch (e) {
      return ConvertResult.fail('EPUB → MD 转换失败: $e');
    }
  }

  /// 递归写入章节内容
  static void _writeChapter(
    StringBuffer buffer,
    EpubChapter chapter,
    int headingLevel,
  ) {
    final title = chapter.Title;
    final htmlContent = chapter.HtmlContent;

    if (title != null && title.isNotEmpty) {
      final prefix = '#'.padRight(headingLevel + 1, '#');
      buffer.writeln('$prefix $title');
      buffer.writeln();
    }

    if (htmlContent != null && htmlContent.isNotEmpty) {
      final markdown = _htmlToMarkdown(htmlContent);
      buffer.writeln(markdown);
      buffer.writeln();
    }

    // 子章节
    if (chapter.SubChapters != null) {
      for (final sub in chapter.SubChapters!) {
        _writeChapter(buffer, sub, headingLevel + 1);
      }
    }
  }

  /// 将 HTML 内容转换为 Markdown
  ///
  /// 支持基本元素：标题、段落、粗体、斜体、列表、链接、图片、换行
  static String _htmlToMarkdown(String html) {
    try {
      final document = html_parser.parse(html);
      final buffer = StringBuffer();

      _convertNode(document.body, buffer);

      return buffer.toString().trim();
    } catch (_) {
      // 降级：简单去除 HTML 标签
      return _stripHtmlSimple(html);
    }
  }

  /// 递归转换 HTML DOM 节点为 Markdown
  static void _convertNode(dom.Node? node, StringBuffer buffer) {
    if (node == null) return;

    if (node is dom.Text) {
      final text = node.text.trim();
      if (text.isNotEmpty) {
        buffer.write(text);
      }
      return;
    }

    if (node is dom.Element) {
      final tag = node.localName?.toLowerCase() ?? '';

      switch (tag) {
        case 'h1':
          buffer.writeln();
          buffer.write('# ');
          _convertChildren(node, buffer);
          buffer.writeln();
          buffer.writeln();
          break;

        case 'h2':
          buffer.writeln();
          buffer.write('## ');
          _convertChildren(node, buffer);
          buffer.writeln();
          buffer.writeln();
          break;

        case 'h3':
          buffer.writeln();
          buffer.write('### ');
          _convertChildren(node, buffer);
          buffer.writeln();
          buffer.writeln();
          break;

        case 'h4':
          buffer.writeln();
          buffer.write('#### ');
          _convertChildren(node, buffer);
          buffer.writeln();
          buffer.writeln();
          break;

        case 'h5':
          buffer.writeln();
          buffer.write('##### ');
          _convertChildren(node, buffer);
          buffer.writeln();
          buffer.writeln();
          break;

        case 'h6':
          buffer.writeln();
          buffer.write('###### ');
          _convertChildren(node, buffer);
          buffer.writeln();
          buffer.writeln();
          break;

        case 'p':
          buffer.writeln();
          _convertChildren(node, buffer);
          buffer.writeln();
          break;

        case 'b':
        case 'strong':
          buffer.write('**');
          _convertChildren(node, buffer);
          buffer.write('**');
          break;

        case 'i':
        case 'em':
          buffer.write('*');
          _convertChildren(node, buffer);
          buffer.write('*');
          break;

        case 'u':
          buffer.write('<u>');
          _convertChildren(node, buffer);
          buffer.write('</u>');
          break;

        case 'a':
          final href = node.attributes['href'] ?? '';
          buffer.write('[');
          _convertChildren(node, buffer);
          buffer.write(']($href)');
          break;

        case 'img':
          final src = node.attributes['src'] ?? '';
          final alt = node.attributes['alt'] ?? '';
          buffer.writeln();
          buffer.write('![$alt]($src)');
          buffer.writeln();
          break;

        case 'br':
          buffer.writeln();
          break;

        case 'hr':
          buffer.writeln();
          buffer.writeln('---');
          buffer.writeln();
          break;

        case 'blockquote':
          buffer.writeln();
          // 简单处理：为每行添加 > 前缀
          final innerBuf = StringBuffer();
          _convertChildren(node, innerBuf);
          for (final line in innerBuf.toString().split('\n')) {
            buffer.writeln('> $line');
          }
          buffer.writeln();
          break;

        case 'ul':
          buffer.writeln();
          _convertChildren(node, buffer);
          buffer.writeln();
          break;

        case 'ol':
          buffer.writeln();
          _convertChildren(node, buffer);
          buffer.writeln();
          break;

        case 'li':
          final parentTag = node.parent?.localName?.toLowerCase() ?? '';
          if (parentTag == 'ol') {
            buffer.write('1. ');
          } else {
            buffer.write('- ');
          }
          _convertChildren(node, buffer);
          buffer.writeln();
          break;

        case 'pre':
        case 'code':
          // 代码块或行内代码
          if (node.parent?.localName?.toLowerCase() == 'pre') {
            buffer.writeln();
            buffer.writeln('```');
            buffer.write(node.text);
            buffer.writeln();
            buffer.writeln('```');
            buffer.writeln();
          } else {
            buffer.write('`');
            buffer.write(node.text);
            buffer.write('`');
          }
          break;

        case 'div':
        case 'section':
        case 'article':
        case 'span':
          // 容器元素，递归处理子节点
          _convertChildren(node, buffer);
          break;

        case 'table':
          // 简单表格转换（提取文本，不去做完整的 Markdown 表格）
          buffer.writeln();
          _convertChildren(node, buffer);
          buffer.writeln();
          break;

        case 'tr':
          buffer.write('| ');
          _convertChildren(node, buffer);
          buffer.writeln(' |');
          break;

        case 'td':
        case 'th':
          _convertChildren(node, buffer);
          buffer.write(' | ');
          break;

        default:
          // 未知标签，递归处理子节点
          _convertChildren(node, buffer);
          break;
      }
    }
  }

  static void _convertChildren(dom.Element element, StringBuffer buffer) {
    for (final child in element.nodes) {
      _convertNode(child, buffer);
    }
  }

  /// 简单去除 HTML 标签（降级方案）
  static String _stripHtmlSimple(String html) {
    var text = html;
    // 替换常见标签为 Markdown 等价
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</?p[^>]*>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp(r'</?div[^>]*>', caseSensitive: false), '\n');
    // 去除所有 HTML 标签
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    // 解码常见 HTML 实体
    text = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ');
    // 清理多余空行
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}

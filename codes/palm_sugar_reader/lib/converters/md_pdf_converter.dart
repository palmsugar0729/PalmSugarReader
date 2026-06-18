import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../services/settings_service.dart';
import 'format_converter.dart';

/// Markdown → PDF 转换器
///
/// 解析 Markdown 为 AST，使用 pdf 包渲染为 PDF 文档。
///
/// 字体加载优先级：
/// 1. PDF 文档内嵌字体（由 pdf 包自动处理）
/// 2. 用户导入的额外字体（设置页 → extraFonts）
/// 3. Windows 系统 CJK 字体（C:\Windows\Fonts\）
/// 4. 内置 Noto Sans SC Regular（10MB，SIL 开源）
class MdPdfConverter {
  MdPdfConverter._();

  /// 缓存的字体，避免每次转换都重新加载
  static pw.Font? _cachedFont;
  static bool _cacheTried = false;

  /// 加载 CJK 字体 — 按优先级链查找
  static Future<pw.Font> _loadCjkFont() async {
    if (_cachedFont != null) return _cachedFont!;
    if (_cacheTried) {
      // 已经尝试过所有来源，直接返回兜底字体
      return await _loadBundledFont();
    }

    // 1. 用户导入的字体
    final userFont = await _loadUserFont();
    if (userFont != null) {
      _cachedFont = userFont;
      _cacheTried = true;
      return _cachedFont!;
    }

    // 2. 系统 CJK 字体
    final systemFont = await _loadSystemFont();
    if (systemFont != null) {
      _cachedFont = systemFont;
      _cacheTried = true;
      return _cachedFont!;
    }

    // 3. 内置字体（兜底）
    _cacheTried = true;
    _cachedFont = await _loadBundledFont();
    return _cachedFont!;
  }

  /// 加载用户导入的字体（取第一个可用的 .ttf/.otf）
  static Future<pw.Font?> _loadUserFont() async {
    try {
      final settings = await SettingsService.load();
      for (final path in settings.extraFonts) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          return pw.Font.ttf(bytes.buffer.asByteData());
        }
      }
    } catch (_) {}
    return null;
  }

  /// 加载 Windows 系统 CJK 字体
  static Future<pw.Font?> _loadSystemFont() async {
    if (!Platform.isWindows) return null;

    const fontDir = r'C:\Windows\Fonts';
    final dir = Directory(fontDir);
    if (!await dir.exists()) return null;

    // 按优先级排列的 CJK 字体文件名
    const candidates = [
      'msyh.ttc', // Microsoft YaHei (微软雅黑)
      'msyhbd.ttc', // Microsoft YaHei Bold
      'simhei.ttf', // SimHei (黑体)
      'simsun.ttc', // SimSun (宋体)
      'msgothic.ttc', // MS Gothic (日文)
      'msmincho.ttc', // MS Mincho (日文)
      'yugothb.ttc', // Yu Gothic (日文)
      'malgun.ttf', // Malgun Gothic (韩文，含汉字)
    ];

    for (final name in candidates) {
      final file = File('$fontDir\\$name');
      if (await file.exists()) {
        try {
          final bytes = await file.readAsBytes();
          return pw.Font.ttf(bytes.buffer.asByteData());
        } catch (_) {
          continue; // 尝试下一个
        }
      }
    }

    return null;
  }

  /// 加载内置 Noto Sans SC Regular（兜底）
  static Future<pw.Font> _loadBundledFont() async {
    final fontData =
        await rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf');
    return pw.Font.ttf(fontData);
  }

  /// Markdown → PDF
  static Future<ConvertResult> convert(
    String sourcePath,
    String outputPath,
  ) async {
    try {
      final file = File(sourcePath);
      if (!await file.exists()) {
        return ConvertResult.fail('源文件不存在: $sourcePath');
      }

      final mdContent = await file.readAsString();
      final pdf = await _renderPdf(mdContent);

      final outFile = File(outputPath);
      await outFile.writeAsBytes(await pdf.save());

      return ConvertResult.ok(outputPath);
    } catch (e) {
      return ConvertResult.fail('MD → PDF 转换失败: $e');
    }
  }

  /// 将 Markdown 文本渲染为 PDF Document
  static Future<pw.Document> _renderPdf(String markdown) async {
    final font = await _loadCjkFont();
    final document = pw.Document();
    final astNodes = md.Document().parse(markdown);

    // 收集顶层块元素，跳过 YAML frontmatter
    final blocks = <md.Node>[];
    bool inFrontmatter = false;

    for (final node in astNodes) {
      if (node is md.Element) {
        final tag = node.tag;

        // 跳过 frontmatter 分隔线
        if (tag == 'hr' && !inFrontmatter && blocks.isEmpty) {
          inFrontmatter = true;
          continue;
        }
        if (tag == 'hr' && inFrontmatter) {
          inFrontmatter = false;
          continue;
        }
        if (inFrontmatter) continue;

        blocks.add(node);
      } else if (node is md.Text &&
          node.text.trim().isNotEmpty &&
          !inFrontmatter) {
        blocks.add(node);
      }
    }

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return _buildPdfWidgets(blocks, font);
        },
      ),
    );

    return document;
  }

  /// 将 AST 块转换为 PDF widgets
  static List<pw.Widget> _buildPdfWidgets(
      List<md.Node> blocks, pw.Font font) {
    final widgets = <pw.Widget>[];

    for (final block in blocks) {
      final w = _convertNode(block, font);
      if (w != null) {
        widgets.add(w);
        widgets.add(pw.SizedBox(height: 4));
      }
    }

    return widgets;
  }

  /// 构建一个带 CJK 字体的基础 TextStyle
  static pw.TextStyle _baseStyle(pw.Font font,
          {double fontSize = 11,
          double height = 1.6,
          pw.FontWeight fontWeight = pw.FontWeight.normal,
          pw.FontStyle fontStyle = pw.FontStyle.normal,
          PdfColor? color}) =>
      pw.TextStyle(
        fontNormal: font,
        fontBold: font,
        fontItalic: font,
        fontBoldItalic: font,
        fontSize: fontSize,
        height: height,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        color: color,
      );

  /// 转换单个 AST 节点为 PDF Widget
  static pw.Widget? _convertNode(md.Node node, pw.Font font) {
    if (node is md.Element) {
      final tag = node.tag;
      final text = _extractText(node);

      switch (tag) {
        case 'h1':
          return pw.Header(
            level: 0,
            text: text,
            textStyle: _baseStyle(font,
                fontSize: 24, fontWeight: pw.FontWeight.bold),
          );

        case 'h2':
          return pw.Header(
            level: 1,
            text: text,
            textStyle: _baseStyle(font,
                fontSize: 20, fontWeight: pw.FontWeight.bold),
          );

        case 'h3':
          return pw.Header(
            level: 2,
            text: text,
            textStyle: _baseStyle(font,
                fontSize: 17, fontWeight: pw.FontWeight.bold),
          );

        case 'h4':
          return pw.Header(
            level: 3,
            text: text,
            textStyle: _baseStyle(font,
                fontSize: 15, fontWeight: pw.FontWeight.bold),
          );

        case 'h5':
          return pw.Header(
            level: 4,
            text: text,
            textStyle: _baseStyle(font,
                fontSize: 13, fontWeight: pw.FontWeight.bold),
          );

        case 'h6':
          return pw.Header(
            level: 5,
            text: text,
            textStyle: _baseStyle(font,
                fontSize: 12, fontWeight: pw.FontWeight.bold),
          );

        case 'p':
          if (text.isEmpty) return null;
          return pw.Paragraph(
            text: text,
            style: _baseStyle(font),
          );

        case 'pre':
          final codeText = node.textContent;
          return pw.Container(
            padding: const pw.EdgeInsets.all(8),
            margin: const pw.EdgeInsets.symmetric(vertical: 4),
            decoration: const pw.BoxDecoration(
              color: PdfColor(0.95, 0.95, 0.95),
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              codeText,
              style: _baseStyle(font, fontSize: 9),
            ),
          );

        case 'code':
          return pw.Paragraph(
            text: node.textContent,
            style: _baseStyle(font, fontSize: 10),
          );

        case 'blockquote':
          return pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 4),
            padding: const pw.EdgeInsets.only(left: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(
                  color: PdfColor(0.64, 0.76, 0.68),
                  width: 3,
                ),
              ),
            ),
            child: pw.Paragraph(
              text: text,
              style: _baseStyle(font,
                  fontStyle: pw.FontStyle.italic,
                  color: const PdfColor(0.4, 0.4, 0.4)),
            ),
          );

        case 'ul':
          return pw.Padding(
            padding: const pw.EdgeInsets.only(left: 16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: _buildListItems(node, font, bullet: '•'),
            ),
          );

        case 'ol':
          return pw.Padding(
            padding: const pw.EdgeInsets.only(left: 16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: _buildListItems(node, font, ordered: true),
            ),
          );

        case 'li':
          if (text.isNotEmpty) {
            return pw.Paragraph(
              text: '• $text',
              style: _baseStyle(font),
            );
          }
          return null;

        case 'hr':
          return pw.Divider();

        case 'table':
          final rows = _findTableRows(node, font);
          if (rows.isNotEmpty) {
            return pw.Table(
              border: pw.TableBorder.all(),
              children: rows,
            );
          }
          return null;

        case 'em':
          if (text.isNotEmpty) {
            return pw.Paragraph(
              text: text,
              style: _baseStyle(font, fontStyle: pw.FontStyle.italic),
            );
          }
          return null;

        case 'strong':
          if (text.isNotEmpty) {
            return pw.Paragraph(
              text: text,
              style: _baseStyle(font, fontWeight: pw.FontWeight.bold),
            );
          }
          return null;

        default:
          if (text.isNotEmpty) {
            return pw.Paragraph(
              text: text,
              style: _baseStyle(font),
            );
          }
          return null;
      }
    }

    // 纯文本节点
    if (node is md.Text && node.text.trim().isNotEmpty) {
      return pw.Paragraph(
        text: node.text.trim(),
        style: _baseStyle(font),
      );
    }

    return null;
  }

  /// 从节点提取纯文本内容
  static String _extractText(md.Node node) {
    final buffer = StringBuffer();

    void collect(md.Node n) {
      if (n is md.Text) {
        buffer.write(n.text);
      } else if (n is md.Element) {
        if (n.children != null) {
          for (final child in n.children!) {
            collect(child);
          }
        }
      }
    }

    collect(node);
    return buffer.toString().trim();
  }

  /// 构建列表项
  static List<pw.Widget> _buildListItems(md.Element listNode, pw.Font font,
      {String bullet = '•', bool ordered = false}) {
    final items = <pw.Widget>[];
    int counter = 0;

    if (listNode.children != null) {
      for (final child in listNode.children!) {
        if (child is md.Element && child.tag == 'li') {
          counter++;
          final prefix = ordered ? '$counter.' : bullet;
          final text = _extractText(child);
          items.add(
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 16,
                  child: pw.Text(
                    prefix,
                    style: _baseStyle(font),
                  ),
                ),
                pw.Expanded(
                  child: pw.Paragraph(
                    text: text,
                    style: _baseStyle(font),
                  ),
                ),
              ],
            ),
          );
          items.add(pw.SizedBox(height: 2));
        }
      }
    }

    return items;
  }

  /// 从 table/thead/tbody 中递归查找 tr 行
  static List<pw.TableRow> _findTableRows(md.Element container, pw.Font font) {
    final rows = <pw.TableRow>[];
    if (container.children == null) return rows;

    for (final child in container.children!) {
      if (child is md.Element) {
        final tag = child.tag;
        if (tag == 'tr') {
          rows.add(_buildTableRow(child, font));
        } else if (tag == 'thead' || tag == 'tbody' || tag == 'tfoot') {
          rows.addAll(_findTableRows(child, font));
        }
      }
    }
    return rows;
  }

  /// 构建表格行
  static pw.TableRow _buildTableRow(md.Element tr, pw.Font font) {
    final cells = <pw.Widget>[];

    if (tr.children != null) {
      for (final child in tr.children!) {
        if (child is md.Element && (child.tag == 'td' || child.tag == 'th')) {
          final isHeader = child.tag == 'th';
          cells.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                _extractText(child),
                style: _baseStyle(font,
                    fontSize: 10,
                    fontWeight:
                        isHeader ? pw.FontWeight.bold : pw.FontWeight.normal),
              ),
            ),
          );
        }
      }
    }

    return pw.TableRow(children: cells);
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:markdown/markdown.dart' as md;
import '../theme.dart';

/// Markdown 阅读器 — 渲染为富文本，支持 LaTeX 数学公式
///
/// 支持的公式语法：
/// - 行内公式：`$...$` 或 `\(...\)`
/// - 块级公式：`$$...$$` 或 `\[...\]`
class MarkdownReader extends StatefulWidget {
  final String filePath;

  const MarkdownReader({super.key, required this.filePath});

  @override
  State<MarkdownReader> createState() => _MarkdownReaderState();
}

class _MarkdownReaderState extends State<MarkdownReader> {
  String _content = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();

      // Markdown 统一按 UTF-8 处理
      final content = utf8.decode(bytes, allowMalformed: true);

      setState(() {
        _content = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('读取失败: $_error', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Markdown(
      data: _content,
      selectable: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      builders: {
        'latex': LatexElementBuilder(
          textStyle: TextStyle(
            fontSize: 16,
            color: AppTheme.textPrimary,
          ),
        ),
      },
      inlineSyntaxes: [LatexInlineSyntax()],
      blockSyntaxes: [LatexBlockSyntax()],
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: TextStyle(fontSize: 16, height: 1.8, color: AppTheme.textPrimary),
        h1: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
        h2: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
        h3: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
        code: TextStyle(
          fontSize: 14,
          backgroundColor: AppTheme.primaryLight.withAlpha(51),
          color: AppTheme.primaryDark,
        ),
        codeblockDecoration: BoxDecoration(
          color: AppTheme.primaryLight.withAlpha(51),
          borderRadius: BorderRadius.circular(8),
        ),
        blockquote: TextStyle(
          fontSize: 16,
          fontStyle: FontStyle.italic,
          color: AppTheme.textSecondary,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: AppTheme.primaryColor, width: 4),
          ),
        ),
        blockquotePadding: const EdgeInsets.only(left: 16),
        listBullet: TextStyle(color: AppTheme.primaryDark),
      ),
    );
  }
}

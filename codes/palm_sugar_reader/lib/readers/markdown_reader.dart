import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:markdown/markdown.dart' as md;
import '../main.dart';
import '../theme.dart';

/// Markdown 阅读器 — 渲染为富文本，支持 LaTeX 数学公式 + 键盘导航
///
/// 支持的公式语法：
/// - 行内公式：`$...$` 或 `\(...\)`
/// - 块级公式：`$$...$$` 或 `\[...\]`
///
/// 键盘快捷键：
/// - ↑/↓：滚动 3 行
/// - PgUp/PgDn：翻页（80% 视口高度）
/// - Home/End：跳到文件开头/末尾
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
  final ScrollController _scrollCtrl = ScrollController();
  double _viewportHeight = 600;

  @override
  void initState() {
    super.initState();
    _loadFile();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _scrollCtrl.dispose();
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!_scrollCtrl.hasClients) return false;

    final key = event.logicalKey;
    final maxScroll = _scrollCtrl.position.maxScrollExtent;
    final pageDelta = _viewportHeight * 0.8;
    final lineDelta = 60.0;
    final shiftHeld = HardwareKeyboard.instance.logicalKeysPressed
        .contains(LogicalKeyboardKey.shiftLeft) ||
        HardwareKeyboard.instance.logicalKeysPressed
            .contains(LogicalKeyboardKey.shiftRight);

    // ↑：向上滚 3 行
    if (key == LogicalKeyboardKey.arrowUp) {
      _scrollCtrl.animateTo(
        (_scrollCtrl.offset - lineDelta).clamp(0, maxScroll),
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
      );
      return true;
    }
    // ↓：向下滚 3 行
    if (key == LogicalKeyboardKey.arrowDown) {
      _scrollCtrl.animateTo(
        (_scrollCtrl.offset + lineDelta).clamp(0, maxScroll),
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
      );
      return true;
    }
    // PgUp / Shift+Space：向上翻页
    if (key == LogicalKeyboardKey.pageUp ||
        (key == LogicalKeyboardKey.space && shiftHeld)) {
      _scrollCtrl.animateTo(
        (_scrollCtrl.offset - pageDelta).clamp(0, maxScroll),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
      return true;
    }
    // PgDn / Space：向下翻页
    if (key == LogicalKeyboardKey.pageDown || key == LogicalKeyboardKey.space) {
      _scrollCtrl.animateTo(
        (_scrollCtrl.offset + pageDelta).clamp(0, maxScroll),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
      return true;
    }
    if (key == LogicalKeyboardKey.home) {
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      return true;
    }
    if (key == LogicalKeyboardKey.end) {
      _scrollCtrl.animateTo(
        maxScroll,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      return true;
    }
    return false;
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

    final fontSize = SettingsProvider.of(context).fontSize;

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportHeight = constraints.maxHeight;
        return Markdown(
          key: const Key('markdown_scroll'),
          data: _content,
          selectable: true,
          extensionSet: md.ExtensionSet.gitHubFlavored,
          builders: {
            'latex': LatexElementBuilder(
              textStyle: TextStyle(
                fontSize: fontSize,
                color: AppTheme.textPrimary,
              ),
            ),
          },
          inlineSyntaxes: [LatexInlineSyntax()],
          blockSyntaxes: [LatexBlockSyntax()],
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: TextStyle(fontSize: fontSize, height: 1.8, color: AppTheme.textPrimary),
            h1: TextStyle(
              fontSize: fontSize * 1.75,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            h2: TextStyle(
              fontSize: fontSize * 1.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            h3: TextStyle(
              fontSize: fontSize * 1.25,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            code: TextStyle(
              fontSize: fontSize * 0.85,
              backgroundColor: AppTheme.primaryLight.withAlpha(51),
              color: AppTheme.primaryDark,
            ),
            codeblockDecoration: BoxDecoration(
              color: AppTheme.primaryLight.withAlpha(51),
              borderRadius: BorderRadius.circular(8),
            ),
            blockquote: TextStyle(
              fontSize: fontSize,
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
          controller: _scrollCtrl,
        );
      },
    );
  }
}

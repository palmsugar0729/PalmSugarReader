import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../theme.dart';
import '../utils/encoding_utils.dart';

/// TXT 阅读器 — 自动检测多语言编码，支持滚动阅读 + 键盘导航
///
/// 编码检测优先级（使用 EncodingUtils）：
/// 1. UTF-8（最通用）
/// 2. GBK / GB2312（中文 Windows ANSI）
/// 3. Shift_JIS（日文）
/// 4. Latin1（西欧字符，兜底）
///
/// 键盘快捷键：
/// - ↑/↓：滚动 3 行
/// - PgUp/PgDn：翻页（80% 视口高度）
/// - Home/End：跳到文件开头/末尾
class TxtReader extends StatefulWidget {
  final String filePath;

  const TxtReader({super.key, required this.filePath});

  @override
  State<TxtReader> createState() => _TxtReaderState();
}

class _TxtReaderState extends State<TxtReader> {
  String _content = '';
  bool _isLoading = true;
  String? _error;
  String _detectedEncoding = 'UTF-8';
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
      final result = await EncodingUtils.detect(bytes);

      setState(() {
        _content = result.text;
        _detectedEncoding = result.encoding;
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
        return Scrollbar(
          controller: _scrollCtrl,
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withAlpha(77),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '编码: $_detectedEncoding',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  _content,
                  style: TextStyle(
                    fontSize: fontSize,
                    height: 1.8,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:charset_converter/charset_converter.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter/material.dart';
import '../theme.dart';

/// TXT 阅读器 — 自动检测多语言编码，支持滚动阅读
///
/// 编码检测优先级：
/// 1. UTF-8（最通用）
/// 2. GBK / GB2312（中文 Windows ANSI）
/// 3. Shift_JIS（日文）
/// 4. Latin1（西欧字符，兜底）
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

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      final result = await _detectEncoding(bytes);

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

  /// 多编码自动检测
  Future<_EncodingResult> _detectEncoding(List<int> bytes) async {
    // 1. 优先尝试 UTF-8
    try {
      Utf8Codec().decode(bytes, allowMalformed: false);
      return _EncodingResult(utf8.decode(bytes), 'UTF-8');
    } catch (_) {}

    // 2. 尝试 GBK（中文 ANSI）
    try {
      final text = gbk.decode(bytes);
      if (_looksLikeValidText(text)) {
        return _EncodingResult(text, 'GBK');
      }
    } catch (_) {}

    // 3. 尝试 Shift_JIS（日文）
    try {
      final text = await CharsetConverter.decode(
        'SHIFT_JIS',
        Uint8List.fromList(bytes),
      );
      if (_looksLikeValidText(text)) {
        return _EncodingResult(text, 'Shift_JIS');
      }
    } catch (_) {}

    // 4. Latin1 兜底
    return _EncodingResult(latin1.decode(bytes), 'Latin1');
  }

  /// 简单启发式：如果文本中替换字符（�）过多，认为编码不正确
  bool _looksLikeValidText(String text) {
    if (text.isEmpty) return false;
    final replacementCount = text.runes.where((r) => r == 0xFFFD).length;
    return replacementCount < text.length * 0.05;
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

    return Scrollbar(
      child: SingleChildScrollView(
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
                fontSize: 16,
                height: 1.8,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EncodingResult {
  final String text;
  final String encoding;

  _EncodingResult(this.text, this.encoding);
}

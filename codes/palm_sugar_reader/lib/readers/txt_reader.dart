import 'dart:io';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/encoding_utils.dart';

/// TXT 阅读器 — 自动检测多语言编码，支持滚动阅读
///
/// 编码检测优先级（使用 EncodingUtils）：
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

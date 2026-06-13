import 'dart:convert';
import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';
import 'package:fast_gbk/fast_gbk.dart';

/// 编码检测结果
class EncodingResult {
  final String text;
  final String encoding;

  const EncodingResult(this.text, this.encoding);
}

/// 编码检测工具 — 自动检测多语言编码
///
/// 检测优先级：
/// 1. UTF-8（最通用）
/// 2. GBK / GB2312（中文 Windows ANSI）
/// 3. Shift_JIS（日文）
/// 4. Latin1（西欧字符，兜底）
class EncodingUtils {
  EncodingUtils._();

  /// 从字节数组检测编码并解码为文本
  static Future<EncodingResult> detect(List<int> bytes) async {
    // 1. 优先尝试 UTF-8
    try {
      Utf8Codec().decode(bytes, allowMalformed: false);
      return EncodingResult(utf8.decode(bytes), 'UTF-8');
    } catch (_) {}

    // 2. 尝试 GBK（中文 ANSI）
    try {
      final text = gbk.decode(bytes);
      if (_looksLikeValidText(text)) {
        return EncodingResult(text, 'GBK');
      }
    } catch (_) {}

    // 3. 尝试 Shift_JIS（日文）
    try {
      final text = await CharsetConverter.decode(
        'SHIFT_JIS',
        Uint8List.fromList(bytes),
      );
      if (_looksLikeValidText(text)) {
        return EncodingResult(text, 'Shift_JIS');
      }
    } catch (_) {}

    // 4. Latin1 兜底
    return EncodingResult(latin1.decode(bytes), 'Latin1');
  }

  /// 简单启发式：如果文本中替换字符（�）过多，认为编码不正确
  static bool _looksLikeValidText(String text) {
    if (text.isEmpty) return false;
    final replacementCount =
        text.runes.where((r) => r == 0xFFFD).length;
    return replacementCount < text.length * 0.05;
  }
}

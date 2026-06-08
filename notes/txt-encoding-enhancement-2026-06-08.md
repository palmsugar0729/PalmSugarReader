---
name: txt-encoding-enhancement
description: TXT 阅读器多编码检测方案（UTF-8 / GBK / Shift_JIS）
metadata:
  type: project
---

## 问题

用户打开中文 ANSI 编码 TXT 文件出现乱码。原有逻辑仅支持 UTF-8 → Latin1 fallback，无法处理 GBK/GB2312 和日文 JIS 编码。

## 方案

引入两个互补的包：

| 包 | 用途 | 类型 |
|----|------|------|
| `fast_gbk` | GBK / GB2312 编解码 | 纯 Dart，同步 API |
| `charset_converter` | Shift_JIS 等平台编码 | Flutter 插件，异步 API，调用 OS 原生转换器 |

## 检测优先级

1. **UTF-8** — 最通用，严格校验（不允许 malformed）
2. **GBK** — 中文 Windows ANSI 默认编码
3. **Shift_JIS** — 日文文本常见编码
4. **Latin1** — 西欧字符兜底

## 启发式校验

解码后检查 Unicode 替换字符（`U+FFFD` `�`）比例，若超过 5% 认为当前编码不正确，继续尝试下一个。

## 代码要点

```dart
Future<String> _detectEncoding(List<int> bytes) async {
  // 1. UTF-8
  try { return utf8.decode(bytes, allowMalformed: false); } catch (_) {}
  
  // 2. GBK
  try { 
    final text = gbk.decode(bytes);
    if (_valid(text)) return text;
  } catch (_) {}
  
  // 3. Shift_JIS
  try {
    final text = await CharsetConverter.decode('SHIFT_JIS', Uint8List.fromList(bytes));
    if (_valid(text)) return text;
  } catch (_) {}
  
  // 4. Latin1 fallback
  return latin1.decode(bytes);
}
```

**Why:** `fast_gbk` 是纯 Dart，速度快；`charset_converter` 复用 OS 能力，支持更多编码而无需维护大量编码表。

**How to apply:** 未来如需支持 EUC-JP、Big5 等，直接在优先级链中追加 `CharsetConverter.decode('EUC-JP', ...)` 即可。

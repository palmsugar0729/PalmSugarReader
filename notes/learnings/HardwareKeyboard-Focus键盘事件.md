---
date: 2026-06-19
tags: [learning, flutter, keyboard, focus, pdfrx]
project: PalmSugarReader
aliases: ["HardwareKeyboard vs Focus.onKeyEvent"]
---

# Flutter 键盘事件处理：HardwareKeyboard vs Focus.onKeyEvent

## 背景

PDF 阅读器使用 `Focus.onKeyEvent` 处理 PgUp/PgDn 等键盘导航，但完全无效。排查发现 `pdfrx` 的 `PdfViewer` 内部有自己的 Focus 节点，拦截了键盘事件。

## 两种 API 对比

| 特性 | `Focus.onKeyEvent` | `HardwareKeyboard.instance.addHandler` |
|------|-------------------|--------------------------------------|
| 层级 | Flutter Focus 树 | 硬件级，Focus 树之前 |
| 被拦截风险 | 高（子 widget 有独立 Focus 节点时） | 低（所有事件必达） |
| 使用方式 | `Focus(onKeyEvent: handler, child: ...)` | `HardwareKeyboard.instance.addHandler(handler)` |
| 生命周期 | 跟随 widget 自动管理 | 需手动 `removeHandler` 在 dispose 中 |
| 返回值 | `KeyEventResult.handled/ignored` | `bool`（true=已处理，停止传播） |

## 何时用 HardwareKeyboard

- 子 widget 来自第三方包（如 `pdfrx`），内部 Focus 行为不可控
- 全局快捷键（如阅读器翻页），不应被子 widget 拦截
- `PageView` / `ListView` 等内置滚动 widget 消费方向键

## 何时用 Focus.onKeyEvent

- widget 树简单，没有多层 Focus 节点
- 仅特定 widget 聚焦时才需要响应（如输入框）

## 代码模板

```dart
class _MyWidgetState extends State<MyWidget> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.space) {
      // 处理空格键
      return true; // true = 已处理，不继续传播
    }
    return false; // false = 未处理，让其他 handler 处理
  }
}
```

## 注意事项

1. **必须 removeHandler**：否则 widget 销毁后 handler 仍然存在，导致内存泄漏和异常
2. **返回 false 让事件继续传播**：只处理自己关心的键，不拦截其他键
3. **Shift 组合键**：`HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft)` 检测 Shift 是否按住
4. **仅响应 KeyDownEvent**：忽略 KeyUpEvent 和 KeyRepeatEvent，避免重复触发

## 相关文件

- [lib/readers/pdf_reader.dart](../../codes/palm_sugar_reader/lib/readers/pdf_reader.dart)
- [lib/readers/epub_reader.dart](../../codes/palm_sugar_reader/lib/readers/epub_reader.dart)
- [lib/readers/txt_reader.dart](../../codes/palm_sugar_reader/lib/readers/txt_reader.dart)
- [lib/readers/markdown_reader.dart](../../codes/palm_sugar_reader/lib/readers/markdown_reader.dart)

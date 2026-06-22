---
date: 2026-06-22
tags: [learning, flutter, stylus, palm-rejection, touch]
project: PalmSugarReader
aliases: ["Flutter 触控笔防误触"]
---

# Flutter PointerDeviceKind 防误触

## 背景

平板端手写标注需要区分笔尖和手掌触摸。手掌碰到屏幕时应被忽略，只有触控笔的输入才产生标注。

## 核心概念

Flutter 的 `PointerEvent` 有 `kind` 字段，类型为 `PointerDeviceKind` 枚举：

- `PointerDeviceKind.stylus` — 触控笔（S Pen / Apple Pencil / 数位板笔）
- `PointerDeviceKind.touch` — 手指/手掌触摸
- `PointerDeviceKind.mouse` — 鼠标
- `PointerDeviceKind.trackpad` — 触控板

在 Android/iOS 上，触控笔和触摸事件会被系统正确分类。S Pen 在接近屏幕时（hover）也产生 `stylus` 事件。

## 代码

```dart
// 在 Listener 的 onPointerDown/Move/Up 中过滤
void _onDown(PointerDownEvent e) {
  if (!widget.allowFingerDraw && e.kind != PointerDeviceKind.stylus) return;
  // ... 正常处理标注绘制
}
```

需要导入 `package:flutter/gestures.dart` 才能使用 `PointerDeviceKind`。

## 注意事项

- 桌面端（Windows）没有 stylus 概念，`kind` 会是 `mouse` 或 `touch`，需要特殊处理或默认允许手指/鼠标
- 提供"允许手指书写"开关给没有触控笔的用户

## 相关文件

- `lib/widgets/annotation_layer.dart` — 实际使用此模式
- `lib/widgets/annotation_toolbar.dart` — "更多"面板中的手指书写开关

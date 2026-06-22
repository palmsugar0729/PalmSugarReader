---
name: annotation-toolbar-pattern
description: 平板端 GoodNotes 风格浮动标注工具栏 + 防误触的架构模式
metadata:
  type: project
---

# 标注工具栏架构模式

## 为什么

平板端手写标注需要常驻工具栏来即时切换工具/颜色/粗细，而不是通过 Dialog 弹窗。同时需要防误触（手掌碰到屏幕不能画线）。

## 设计

### 工具栏模式

- **移动端**：`AnnotationToolbar` widget — 常驻底部两行工具栏（工具行 + 颜色/粗细行），可折叠为 44x44 浮动圆钮。所有切换即时生效，无确认步骤。
- **桌面端**：保留原有 Dialog 流程（选工具类型 → 颜色选择器），鼠标操作 Dialog 不是痛点。
- **平台判断**：`AnnotationToolbar.isSupported` = `Platform.isAndroid || Platform.isIOS`

### 防误触

- Flutter 的 `PointerEvent.kind` 可区分 `PointerDeviceKind.stylus`（笔尖）和 `PointerDeviceKind.touch`（手指/手掌）
- `AnnotationLayer` 在 `_onDown/_onMove/_onUp` 开头过滤：`if (!widget.allowFingerDraw && e.kind != PointerDeviceKind.stylus) return;`
- `allowFingerDraw` 默认为 false，从工具栏"手指书写"开关控制

### 撤销机制

- `AnnotationService.popLast(filePath)` — 删除文件最后一笔标注
- `AnnotationLayer` 通过 `refreshCounter` 参数感知重载需求（didUpdateWidget 检测变化后 reload）
- 工具栏撤销按钮 → Reader `_handleUndo()` → `AnnotationService.popLast()` → `setState` 递增 counter → AnnotationLayer 自动重载

## 关键代码路径

- [[annotation-layer]]: `lib/widgets/annotation_layer.dart`
- [[annotation-toolbar]]: `lib/widgets/annotation_toolbar.dart`
- [[annotation-service]]: `lib/services/annotation_service.dart`

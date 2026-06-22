---
date: 2026-06-21
tags: [prd, flutter, annotation, handwriting, palm-rejection, toolbar]
project: PalmSugarReader
aliases: ["标注工具栏重构计划", "Annotation Toolbar Plan"]
---

# 平板手写标注工具栏重构 + 防误触 实施计划

## Context

当前 PalmSugarReader 的标注入口需要经过两个串行 Dialog（选工具类型 → 颜色/粗细/画笔选择器），中途要改任何设置必须退出标注再重新进入。平板端作为手写主力场景，这个流程完全不可用。同时缺少防误触机制，手掌碰到屏幕就会画出乱线。

目标：做一个 GoodNotes 风格的常驻浮动工具栏，支持即时切换工具/颜色/粗细，加上橡皮擦和撤销；并加入基于 `PointerDeviceKind.stylus` 的防误触滤镜。橡皮擦同时覆盖桌面端（桌面端 Dialog 流程也加入橡皮擦选项）。

## 设计原则

- **MVP 优先**：先做核心的工具栏框架 + 防误触，橡皮擦/撤销按简单方式做
- **不影响桌面端**：桌面端保留现有 Dialog 流程（鼠标操作 Dialog 不是问题），平板/手机端用新工具栏
- **一支笔原则**：默认只响应 stylus，手掌自动忽略；提供"手指书写"开关给没笔的用户
- **收起不挡内容**：工具栏可折叠成一个小圆钮

---

## 1. 新建 `AnnotationToolbar` widget

**文件**：`lib/widgets/annotation_toolbar.dart`（新建）

### 1.1 职责

独立的浮动工具栏，管理标注工具的 **全部 UI 状态**，通过回调向外报告变化。替换现在的：
- `enterAnnotationMode()` 中的两个 Dialog
- `_buildIndicator()` 底部纯展示条

### 1.2 状态

```dart
AnnotationType _tool       // freeform | highlight | underline | note | eraser
int _brushType             // 0=pencil, 1=pen, 2=watercolor (freeform 时有效)
Color _color               // 当前颜色
double _opacity            // 0.1~1.0
double _thickness          // 2~40
bool _collapsed            // 工具栏是否收起
bool _allowFingerDraw      // 是否允许手指书写
```

### 1.3 布局（展开态）

```
┌──────────────────────────────────────────────────┐
│ [笔][画笔][水彩][荧光笔][橡皮][便签]  [↩撤销] [✕退出] │  ← 工具行
│ [⚫][🟡][🟢][🔵][🔴][🟠]        [─●──] [⚙更多]  │  ← 颜色 + 粗细
└──────────────────────────────────────────────────┘
```

- **第一行**：工具切换（IconButton 组，当前工具高亮）
- **第二行**：6 个预设色块 + 粗细预设按钮（S / M / L）+ 更多按钮
- "更多"按钮弹出简单的 bottom sheet：HEX 输入、精确粗细滑条、不透明度滑条、手指书写开关（复用现有 color_picker.dart 的部分 UI，但不是 Dialog 形式）
- 橡皮擦：实现为"白笔画"——在 freeform 路径上用背景色覆盖。简单有效，第一版不做划擦删除。
- 工具切换即时生效，无确认步骤

### 1.4 收起态

工具栏收起为一个 44x44 的圆形 floating button，显示当前颜色圆点 + 笔尖图标。点击展开。长按可拖动位置。

### 1.5 对外接口

```dart
class AnnotationToolbar extends StatefulWidget {
  final AnnotationToolConfig initialConfig;
  final void Function(AnnotationToolConfig config) onChanged;
  final VoidCallback onUndo;
  final VoidCallback onExit;
}
```

`AnnotationToolConfig` 是一个简单的数据类，包含 tool, brushType, color, opacity, thickness, allowFingerDraw。

### 1.6 实现要点

- 用 `AnimatedContainer` + `AnimatedPosition` 做展开/收起动画
- 工具栏 dock 在屏幕底部，`SafeArea` 包裹
- 使用 `Material` + 圆角 + 轻微阴影，风格贴近 AppTheme
- 预设色块沿用 `color_picker.dart` 中已有的 6 色（黄/绿/蓝/粉/橙/黑）
- 粗细预设：S=3, M=8, L=16（对应铅笔/画笔/水彩笔的合理粗细）

---

## 2. AnnotationLayer 改动

**文件**：`lib/widgets/annotation_layer.dart`

### 2.0 Bug 修复：退出标注后标注不可见

**现象**：Android 平板端，标注模式内画的标注退出后全部看不见，再进入标注模式才显示。

**根因**：`build()` 方法中 `if (!widget.enabled) return widget.child;` 直接跳过了整个 Stack，包括渲染已保存标注的 `CustomPaint`（`_AnnPainter`）。

**修复**：拆开渲染与交互——
- `CustomPaint`（已保存标注）始终渲染，不受 `enabled` 控制
- `Listener` + `GestureDetector`（新标注事件）仅在 `enabled == true` 时叠加

```dart
// 修复后
@override
Widget build(BuildContext context) {
  return LayoutBuilder(
    builder: (context, constraints) {
      _pageSize = Size(constraints.maxWidth, constraints.maxHeight);
      // 标注渲染始终存在
      final stack = Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          widget.child,
          CustomPaint(size: _pageSize, painter: _AnnPainter(...)),
          if (_drawing && widget.enabled) _buildPreview(),
        ],
      );
      // 仅在启用时叠加交互层
      if (!widget.enabled) return stack;
      return Listener(
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onUp,
        child: GestureDetector(
          onTapUp: _onTap,
          behavior: HitTestBehavior.translucent,
          child: stack,
        ),
      );
    },
  );
}
```

### 2.1 防误触

在 `_onDown`, `_onMove`, `_onUp` 三个方法开头，各加一行：

```dart
void _onDown(PointerDownEvent e) {
  if (!widget.enabled) return;
  if (!widget.allowFingerDraw && e.kind != PointerDeviceKind.stylus) return;
  // ... 原有逻辑
}
```

### 2.2 新增参数

`AnnotationLayer` 新增：

```dart
final bool allowFingerDraw;  // default false
```

### 2.3 注意

- `PointerDeviceKind.stylus` 在 Android/iOS 上正确映射到 S Pen / Apple Pencil
- 桌面端（Windows）没有 stylus 概念，`kind` 会是 `mouse` 或 `touch`，桌面端保留手指/鼠标绘制行为

---

## 3. 橡皮擦支持（桌面 + 平板 双端覆盖）

### 3.1 Annotation 模型扩展

**文件**：`lib/models/annotation.dart`

新增 `AnnotationType.eraser` 枚举值。橡皮擦产生的标注也是一个 Annotation：
- type = eraser
- points 存储擦除路径
- colorValue 存背景色（白色）
- thickness 比正常笔触粗（~20）

### 3.2 MVP 方案

第一版橡皮擦用"白色粗笔"模拟——`brushType=pen, color=white, thickness=20`。不引入 `BlendMode.clear`，避免 PDF 页面上的 Canvas 兼容问题。

### 3.3 平板端集成

工具栏工具行有独立的橡皮擦按钮，点击切换到 eraser 模式，toolbar config 中 `tool = AnnotationType.eraser` 传给 AnnotationLayer。

### 3.4 桌面端集成

桌面端保留 Dialog 流程，在工具类型选择对话框（`SimpleDialog`）中新增"橡皮擦"选项：
```dart
SimpleDialogOption(
  onPressed: () => Navigator.pop(ctx, AnnotationType.eraser),
  child: const ListTile(leading: Icon(Icons.auto_fix_high, color: Colors.grey), title: Text('橡皮擦')),
),
```
选橡皮擦后跳过颜色选择器（橡皮擦固定白色粗笔）或仍弹出但颜色/粗细不可编辑，直接进入标注模式。

---

## 4. 撤销支持

### 4.1 AnnotationService 新增方法

**文件**：`lib/services/annotation_service.dart`

```dart
/// 删除该文件最后一笔标注
static Future<Annotation?> popLast(String filePath) async { ... }
```

实现：load → remove last → save。

### 4.2 AnnotationLayer 的撤销回调

在 `AnnotationLayer` 中新增 `VoidCallback? onUndo`。调用时从 `_annotations` 移除最后一笔，调用 `AnnotationService.popLast()`。

---

## 5. 三个 Reader 统一改造

### 5.1 改动模式（不改动公共基类）

1. 删除 `enterAnnotationMode()` 中的两个 Dialog 调用
2. 删除 `_buildIndicator()` 方法
3. 直接在 `build()` 中用 `AnnotationToolbar` 替换原来底部指示条
4. 新增 `_handleToolbarChange(AnnotationToolConfig)` 方法
5. 新增 `_handleUndo()` 方法

### 5.2 PDF Reader (`pdf_reader.dart`)

- 替换 Dialog 流程 → 工具栏直接 setState
- 缩放按钮 `bottom: _annotMode ? 110 : 16`（适配工具栏高度）
- 传递 `allowFingerDraw` 给 AnnotationLayer

### 5.3 EPUB Reader (`epub_reader.dart`)

- 同上替换
- **修复缺失退出按钮**：新工具栏自带退出按钮，自然修复
- 工具栏放在分页栏之上

### 5.4 Image Reader (`image_reader.dart`)

- 同上替换
- FAB 列 `bottom: _annotMode ? 110 : 16`
- InteractiveViewer 的 panEnabled/scaleEnabled 逻辑不变

---

## 6. 布局协调

- 工具栏展开态高度约 96px（工具行 44px + 颜色行 44px + 内边距 8px）
- PDF/Image Reader 缩放按钮 `bottom` 从 60 → 110
- EPUB Reader 工具栏放在分页栏之上

---

## 7. 文件清单与变更量估计

| 文件 | 操作 | 估计行数变化 |
|---|---|---|
| `lib/widgets/annotation_toolbar.dart` | **新建** | ~350 行 |
| `lib/widgets/annotation_layer.dart` | 修改 | +15 行 |
| `lib/models/annotation.dart` | 修改 | +5 行 |
| `lib/services/annotation_service.dart` | 修改 | +15 行 |
| `lib/readers/pdf_reader.dart` | 修改 | ~-60, +50 行 |
| `lib/readers/epub_reader.dart` | 修改 | ~-60, +50 行 |
| `lib/readers/image_reader.dart` | 修改 | ~-60, +50 行 |
| `lib/widgets/color_picker.dart` | 保持不变 | — |

---

## 8. 实现顺序

0. **Step 0: 修复标注退出后不可见 Bug** — AnnotationLayer 拆分渲染与交互：标注 CustomPaint 始终渲染，Listener/GestureDetector 仅在 enabled 时叠加（1 个文件，~20 行改动）
1. **Step 1: AnnotationToolbar 骨架** — 新建 widget，展开/收起/切换
2. **Step 2: 防误触** — AnnotationLayer stylus 过滤（改动最小，风险最低）
3. **Step 3: 橡皮擦 + 撤销** — 模型扩展 + AnnotationService.popLast + 桌面端 Dialog 加入橡皮擦选项
4. **Step 4: PDF Reader 集成** — 第一个完整验证
5. **Step 5: Image Reader 集成** — InteractiveViewer 协调
6. **Step 6: EPUB Reader 集成** — 修复缺失退出按钮
7. **Step 7: 桌面端兼容** — 确认 Dialog 流程不受影响

---

## 9. 验证方法

1. **Android 平板实测**：
   - 进入标注模式 → 工具栏出现在底部
   - 切换笔/画笔/水彩笔 → 画线确认笔触变化
   - 点击色块 → 颜色即时切换
   - 粗细 S/M/L 切换
   - 橡皮擦擦除之前画的内容
   - 撤销按钮删除最后一笔
   - 收起/展开工具栏
   - 手掌放在屏幕上同时用笔画 → 不产生乱线
   - 开启"手指书写"开关 → 手指可以画
   - 退出标注 → 工具栏消失，恢复阅读模式

2. **Windows 桌面端**：确认标注入口仍为 Dialog 流程，功能不受影响

3. **功能回归**：高亮、划线、批注功能在三个阅读器中均正常工作

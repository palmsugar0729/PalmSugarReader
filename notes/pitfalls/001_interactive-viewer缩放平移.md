---
date: 2026-06-19
tags: [pitfall, flutter, interactive-viewer, gesture, matrix]
project: PalmSugarReader
status: resolved
aliases: ["InteractiveViewer 缩放后焦点偏移"]
---

# InteractiveViewer 缩放后焦点偏移且无法拖拽

**状态**：🟢 已解决
**发现日期**：2026-06-19
**关联**：[[2026-06-19_开发日志]]

## 现象

1. 点击放大按钮后，图片"飞"到右下角，焦点严重偏移
2. 放大后无法拖拽平移
3. PDF 和图片都存在同样问题

## 根因

### 根因 1：缩放矩阵以原点为中心

`_zoomIn()` 直接赋值：
```dart
_tc.value = Matrix4.diagonal3Values(_currentScale, _currentScale, 1.0);
```

`Matrix4.diagonal3Values` 的缩放中心是坐标原点 `(0,0)`（左上角），不是视口中心。当 `Center` + `Image` 被缩放时，图片中心会向右下方偏移 `scale × ½viewport`。

### 根因 2：平移分量被清零

对角矩阵没有 `translation` 分量，用户之前的拖拽位置被完全重置。

### 根因 3：`AnnotationLayer` 拦截手势

即使 `enabled: false`，`AnnotationLayer` 仍然叠加了 `Listener` + `GestureDetector` + `CustomPaint`，参与命中测试，干扰了 `InteractiveViewer` 的手势竞技。

### 根因 4：`InteractiveViewer` 边界限制

默认 `boundaryMargin: EdgeInsets.zero` 在某些缩放比例下会触发 `_clampMatrix` 的异常分支，强制把图片拽到错误位置。

## 解决方案

### 根本修复 1：以视口中心为焦点缩放

```dart
final toCenter = Matrix4.translationValues(center.dx, center.dy, 0);
final scaleM = Matrix4.diagonal3Values(scaleDelta, scaleDelta, 1.0);
final back = Matrix4.translationValues(-center.dx, -center.dy, 0);
_tc.value = toCenter * scaleM * back * matrix;
```

公式：`新矩阵 = T(center) · S(scaleDelta) · T(-center) · 旧矩阵`

### 根本修复 2：`AnnotationLayer` 透明穿透

```dart
@override
Widget build(BuildContext context) {
  if (!widget.enabled) return widget.child; // 直接返回，不叠加任何层
  // ... 标注模式下的 Listener + GestureDetector + CustomPaint
}
```

### 根本修复 3：解除边界限制

```dart
InteractiveViewer(
  boundaryMargin: const EdgeInsets.all(double.infinity),
  // ...
)
```

### 根本修复 4：PDF 文本选择冲突

```dart
PdfViewerParams(
  enableTextSelection: false, // 避免文本选择和鼠标拖拽冲突
)
```

## 预防

- [ ] 任何在 `InteractiveViewer` 外层包裹的 `GestureDetector`/`Listener` 都需要检查是否干扰 pan/scale 手势
- [ ] 外部修改 `TransformationController.value` 时，使用矩阵乘法而非直接覆盖对角矩阵
- [ ] 桌面端 `InteractiveViewer` 的 pan 手势可能与 `SelectionArea`/`TextSelection` 冲突，需二选一

---
name: home-screen-batch-delete
description: 首页最近文件列表的移除与批量删除交互设计
metadata:
  type: project
---

## 需求

用户希望：
1. 移除不想看的单个文件记录
2. 支持批量删除

## 交互设计

### 单个移除

- **滑动删除**：列表项向右滑动（`Dismissible.endToStart`），显示红色删除背景
- **二次确认**：滑动后弹出 AlertDialog 确认，防止误操作

### 批量删除

- **进入选择模式**：
  - 方式一：长按任意列表项
  - 方式二：点击 AppBar 右上角「批量选择」图标
- **选择模式 UI**：
  - AppBar 变为选择状态，左侧显示「关闭」按钮，标题显示已选数量
  - 列表项左侧出现 Checkbox
  - 点击列表项切换选中状态
  - AppBar 右侧提供「全选」按钮
- **底部操作栏**：选择模式下底部显示红色「删除」按钮，未选中时禁用
- **二次确认**：点击删除后弹出确认对话框，显示删除数量

### 状态管理

使用 `StatefulWidget` 内建状态：
- `_isSelectionMode` — 是否处于选择模式
- `_selectedIndices` — `Set<int>`，记录选中项的索引

## 代码要点

```dart
// 选择模式切换
void _toggleSelectionMode() {
  setState(() {
    _isSelectionMode = !_isSelectionMode;
    _selectedIndices.clear();
  });
}

// 批量删除（从后往前删，避免索引错乱）
void _deleteSelected() {
  final sorted = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
  for (final i in sorted) {
    _recentBooks.removeAt(i);
  }
}
```

**Why:** 滑动删除符合移动端直觉，批量删除通过选择模式降低误触风险。长按和顶部按钮两种入口覆盖不同使用习惯。

**How to apply:** 后续如需拖拽排序、搜索过滤，可在现有 `ListView.builder` 基础上继续扩展。

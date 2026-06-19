# 讨论存档 — 2026-06-19

> 主题：Bug 修复 + Phase 5 格式转换 + 文档归档

---

## 一、Bug 修复

### 1.1 图片/PDF 放大后无法拖拽 + 焦点偏移

**现象**：放大后图片焦点偏到角落，拖拽无效。PDF 同样问题。

**根因**：
1. `Matrix4.diagonal3Values` 缩放中心是 (0,0)，不是视口中心
2. 直接覆盖矩阵丢失已有平移
3. `AnnotationLayer` 在 `enabled=false` 时仍叠加 `Listener` + `GestureDetector`，干扰手势竞技
4. `InteractiveViewer` 默认 `boundaryMargin: EdgeInsets.zero` 在某些缩放比例下异常

**修复**：见 `001_interactive-viewer缩放平移.md`

### 1.2 批量导入文件重启后消失

**根因**：`BookmarkService.addOrUpdate` 异步调用未 `await`

**修复**：循环中用 `Future.wait` 等待所有保存完成

### 1.3 SnackBar "打开"按钮点击无反应

**根因**：SnackBar dismiss 动画与 `Navigator.push` 同帧冲突

**修复**：`WidgetsBinding.instance.addPostFrameCallback` 延迟到下一帧

### 1.4 图片转 PDF 垂直居中

**用户反馈**：一图一页时图片垂直居中不够好，希望顶部对齐

**修复**：`pw.Center` 改为 `pw.Align(alignment: pw.Alignment.topCenter)`

---

## 二、Phase 5 格式转换

### 2.1 图片 → PDF
- 单图：一图一页，顶部对齐
- 多图：紧凑 2×2 网格 / 一图一页两种模式
- 主界面批量选择模式新增"转PDF"按钮

### 2.2 MD → EPUB
- 初版只有 EPUB 2 结构（toc.ncx），现代阅读器无法打开
- 重写为 EPUB 3 标准：
  - 补 `nav.xhtml`（`epub:type="toc"`）
  - `content.opf` 升级 3.0
  - 内嵌中文阅读 CSS
  - 封面页支持
  - 智能分章（优先 `#`，无则降级 `##`）
- 参考了 Python 项目 `easy_EPUB_generator` 的结构

### 2.3 MD → TXT
- 已有实现（`TxtMdConverter.toText`），无需新建

### 2.4 依赖更新
- `pubspec.yaml` 添加 `archive: ^3.4.0`（手写 EPUB zip）
- `pubspec.yaml` 添加 `desktop_drop: ^0.5.0`（外部文件拖拽）

---

## 三、新功能：外部文件拖拽

- 使用 `desktop_drop` 包
- `HomeScreen` 的 body 包裹 `DropTarget`
- 拖入支持格式 → 直接打开
- 拖入不支持格式 → 弹出警告

---

## 四、文档归档

| 文件 | 说明 |
|------|------|
| `docs/PRD.md` | 标注 Bug 修复、Phase 5 转换、菜单栏/拖拽 标记为已完成 |
| `README.md` | 已完成列表同步，待开发列表精简 |
| `AGENTS.md` | 重写为完整 AI 开发指引（架构图 + 6 个踩坑记录） |
| `notes/2026-06-19_开发日志.md` | 今日所有工作的 Obsidian 格式日志 |
| `notes/pitfalls/` | 3 个踩坑记录（缩放平移、批量导入、EPUB3） |
| `notes/learnings/` | 1 个学习笔记（手写 EPUB3 结构） |

同步到 Obsidian vault：`MyKnowledgeBase/10_notes/vibecoding/`

---

## 五、待办

- [ ] MD→EPUB 图片路径自动重写（当前只收集未替换 XHTML 中的 `src`）
- [ ] MD→EPUB 分章级别 UI 选择（`#` vs `##`）
- [ ] 用户系统本地 mock

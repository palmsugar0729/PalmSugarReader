# PalmSugarReader — AI 开发指引

> 本文件面向 AI 编码助手（Claude / Cursor / Copilot 等），记录项目架构、代码规范与常见陷阱，确保协作一致性。

---

## 1. 项目概览

**PalmSugarReader** 是一款基于 Flutter 的轻量跨平台阅读器，支持 PDF / EPUB / TXT / Markdown / 图片五种格式，覆盖 Windows、Android、iOS 三端。

核心定位：**阅读 + 标注 + 格式转换**，不做臃肿的文档编辑。

- **仓库根目录**: `d:/WorkSpace/projects/mix/PalmSugarReader/`
- **Flutter 项目路径**: `codes/palm_sugar_reader/`
- **构建输出**: `codes/palm_sugar_reader/build/windows/x64/runner/Release/`

---

## 2. 技术栈与关键依赖

| 层 | 选型 | 用途 |
|---|---|---|
| 框架 | Flutter 3.44.1+ | 三端统一 UI |
| PDF 阅读 | `pdfrx: ^1.3.5` | 基于 PDFium 的 PDF 渲染 |
| EPUB 阅读 | `epubx: ^4.0.0` + 自研 `PageView` | 懒加载、水平翻页 |
| Markdown | `flutter_markdown: ^0.7.7` + `markdown: ^7.3.1` | 渲染 + AST 解析 |
| 数学公式 | `flutter_markdown_latex: ^0.3.4` + `flutter_math_fork: ^0.7.4` | LaTeX 支持 |
| PDF 生成 | `pdf: ^3.8.4` | MD → PDF |
| EPUB 生成 | `archive: ^3.4.0` + 手写 XML | MD → EPUB（EPUB 3 标准） |
| 文件拖拽 | `desktop_drop: ^0.5.0` | 桌面端外部文件拖入 |
| 持久化 | `path_provider: ^2.1.5` + JSON | 书签/设置/标注 |

---

## 3. 项目结构

```
codes/palm_sugar_reader/lib/
├── main.dart                 # 入口 + SettingsProvider（InheritedNotifier）
├── theme.dart                # 鼠尾草绿 #A3C1AD + Material3 主题
├── models/
│   ├── book.dart             # 书籍模型（格式检测、JSON 序列化）
│   └── annotation.dart       # 标注模型（相对坐标 0~1）
├── screens/
│   ├── home_screen.dart      # 首页：最近列表 + 文件选择 + 批量操作 + 拖拽接收
│   ├── reader_screen.dart    # 阅读器壳：顶部菜单栏 + 格式分发
│   ├── settings_screen.dart  # 设置：批量导入/字号/背景/字体/帮助
│   └── ...
├── readers/
│   ├── pdf_reader.dart       # pdfrx 包装 + 标注 overlay
│   ├── epub_reader.dart      # epubx + PageView 自研翻页
│   ├── txt_reader.dart       # 多编码检测 + ScrollController
│   ├── markdown_reader.dart  # flutter_markdown + 字号联动
│   └── image_reader.dart     # InteractiveViewer + 标注 overlay
├── converters/
│   ├── format_converter.dart # 转换路由协调器（直接转换 + 链式 MD 中转）
│   ├── txt_md_converter.dart # TXT ↔ MD（编码检测 + YAML frontmatter）
│   ├── epub_md_converter.dart# EPUB → MD（epubx 解析章节）
│   ├── md_pdf_converter.dart # MD → PDF（CJK 字体链：用户/系统/内置）
│   ├── md_epub_converter.dart# MD → EPUB（EPUB 3：nav.xhtml + CSS + 封面）
│   └── image_pdf_converter.dart # 图片 → PDF（单图/多图 紧凑/单页）
├── services/
│   ├── bookmark_service.dart # 最近文件 JSON 持久化
│   ├── settings_service.dart # 设置 JSON 持久化 + 缓存
│   └── annotation_service.dart # 标注 JSON CRUD
├── widgets/
│   ├── top_menu_bar.dart     # 顶部自动隐藏菜单栏（MouseRegion + AnimatedSlide）
│   ├── annotation_layer.dart # 透明标注画布（Pointer 事件 + CustomPaint）
│   └── color_picker.dart     # 色盘 + 不透明度/粗细滑条
└── utils/
    ├── file_utils.dart       # 扩展名、路径工具
    └── encoding_utils.dart   # 多编码检测（GBK/UTF-8/Shift-JIS/Big5）
```

---

## 4. 核心设计模式

### 4.1 阅读器分发

`ReaderScreen._buildReader()` 根据 `BookFormat` 分发到对应 Reader Widget：

```dart
Widget _buildReader() => switch (book.format) {
  BookFormat.image => ImageReader(key: _imageReaderKey, filePath: book.filePath),
  BookFormat.pdf => PdfReader(key: _pdfReaderKey, filePath: book.filePath),
  // ...
};
```

每个 Reader 都是独立的 `StatefulWidget`，通过 `GlobalKey` 暴露 `enterAnnotationMode()` 等方法给 `ReaderScreen` 的顶部菜单栏调用。

### 4.2 格式转换：Markdown 为枢纽

```dart
// 直接转换
TXT → MD,  MD → TXT,  MD → PDF,  MD → EPUB
EPUB → MD,  图片 → PDF

// 链式转换（通过 MD 中转）
EPUB → MD → PDF
TXT → MD → EPUB
```

`FormatConverter._convertViaMarkdown()` 处理两步链式转换，自动清理临时 `.tmp.md` 文件。

### 4.3 标注系统：AnnotationLayer

- **坐标归一化**：所有标注存储 0~1 相对比例，天然缩放跟随
- **事件分层**：`enabled == false` 时直接返回 `child`，不叠加任何 `Listener`/`GestureDetector`，避免干扰底层手势
- **渲染**：`CustomPaint` 绘制高亮矩形 / 划线 / 便签标记

### 4.4 状态管理（MVP 阶段）

- 全局主题/字号：`SettingsProvider`（`InheritedNotifier` + `ChangeNotifier`）
- 页面级状态：`StatefulWidget` + `setState`
- 持久化：`SettingsService` / `BookmarkService` / `AnnotationService` 直接读写 JSON

---

## 5. 代码规范

### 5.1 命名

- 文件：`snake_case.dart`
- 类：`PascalCase`
- 私有成员：`_leadingUnderscore`
- 常量：`kConstantName` 或 `UPPER_SNAKE_CASE`

### 5.2 导入顺序

```dart
// 1. Dart SDK
import 'dart:io';

// 2. Flutter
import 'package:flutter/material.dart';

// 3. 第三方包（按字母序）
import 'package:file_picker/file_picker.dart';
import 'package:pdfrx/pdfrx.dart';

// 4. 项目内部（相对路径，按字母序）
import '../models/book.dart';
import '../theme.dart';
```

### 5.3 错误处理

- 文件 IO 操作包 `try-catch`，静默失败时注释说明不影响用户体验
- 转换器返回 `ConvertResult`（`success` + `outputPath` + `errorMessage`），由调用方决定如何展示

---

## 6. 已知陷阱与踩坑记录

### 6.1 InteractiveViewer 缩放后焦点偏移

**现象**：按钮缩放后图片焦点偏到角落，且无法拖拽。

**根因**：
1. `Matrix4.diagonal3Values(s, s, 1)` 缩放中心是坐标原点 `(0,0)`，不是视口中心
2. 直接覆盖矩阵会丢失已有的平移分量
3. `AnnotationLayer` 在 `enabled=false` 时仍然叠加 `Listener` + `GestureDetector`，干扰手势竞技

**修复**：
- 使用矩阵乘法实现以视口中心为焦点的缩放：`T(center) * S(scaleDelta) * T(-center) * M`
- `AnnotationLayer` 在 `!enabled` 时直接返回 `widget.child`
- `InteractiveViewer` 添加 `boundaryMargin: EdgeInsets.all(double.infinity)` 解除平移边界限制

### 6.2 批量导入文件未持久化

**现象**：批量导入的文件重启后消失。

**根因**：`BookmarkService.addOrUpdate()` 是异步的，但 `_checkSiblingFiles` 循环中没有 `await`，文件还没写入应用就被关闭。

**修复**：循环中用 `Future.wait()` 等待所有保存完成。

### 6.3 SnackBarAction 导航无响应

**现象**：转换成功后 SnackBar 的"打开"按钮点击无反应。

**根因**：`SnackBar` dismiss 动画和 `Navigator.push` 在同一帧冲突。

**修复**：`onPressed` 中包一层 `WidgetsBinding.instance.addPostFrameCallback` 延迟到下一帧执行导航。

### 6.4 EPUB 显示不出来

**现象**：MD → EPUB 转换成功，但阅读器打不开。

**根因**：手写 EPUB 只有 EPUB 2 的 `toc.ncx`，缺少 **EPUB 3 必须的 `nav.xhtml`**，现代阅读器（Apple Books、多看等）拒绝解析。

**修复**：
- 添加 `OEBPS/nav.xhtml`（`epub:type="toc"`）
- `content.opf` 版本改为 `3.0`
- manifest 中声明 `<item properties="nav">`
- 内嵌 CSS 确保排版正常

### 6.5 图片转 PDF 对齐

**现象**：一图一页时图片垂直居中，用户期望顶部对齐。

**修复**：`pw.Center` 改为 `pw.Align(alignment: pw.Alignment.topCenter)`。

### 6.6 `archive` 包非直接依赖

**现象**：使用 `package:archive/archive.dart` 时报 "isn't a dependency"。

**修复**：在 `pubspec.yaml` 中显式添加 `archive: ^3.4.0`（即使 `epubx` 已间接依赖）。

---

## 7. 构建与发布

### Windows Release 构建

```bash
cd codes/palm_sugar_reader
flutter build windows --release
```

输出路径：`build/windows/x64/runner/Release/palm_sugar_reader.exe`

### 添加新依赖后

```bash
flutter pub get
flutter build windows --release
```

---

## 8. 参考文档

- [docs/PRD.md](docs/PRD.md) — 产品需求文档
- [docs/implementation-plan-2.0.md](docs/implementation-plan-2.0.md) — 实施计划
- [docs/discussion-*.md](docs/) — 开发讨论留档
- [notes/](notes/) — 技术决策与踩坑记录（Obsidian 同步）

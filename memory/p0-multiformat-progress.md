---
name: p0-multiformat-progress
description: P0 多格式阅读功能开发进度记录
metadata:
  type: project
---

## 进度概览（截至 2026-06-08）

P0 多格式阅读共 5 种格式，已完成 5/5。

### 已完成 ✅

1. **项目初始化**：Flutter 3.44.1 项目 `palm_sugar_reader` 已创建，支持 Windows / Android / iOS
2. **主色调配置**：`#A3C1AD`（鼠尾草绿 Sage Green）已写入 `lib/theme.dart`，包含完整的 Material3 主题
3. **基础框架**：
   - 首页 `HomeScreen`：文件选择按钮 + 最近文件列表 + 空状态提示
   - 阅读器路由壳 `ReaderScreen`：根据 `BookFormat` 自动分发到对应阅读器
   - 文件类型识别 `FileUtils`：自动检测扩展名并映射到格式枚举
4. **图片阅读器** `ImageReader`：支持双指缩放、平移、双击放大
5. **TXT 阅读器** `TxtReader`：自动多编码检测（UTF-8 → GBK → Shift_JIS → Latin1），显示检测到的编码
6. **Markdown 阅读器** `MarkdownReader`：使用 `flutter_markdown` 渲染，支持 LaTeX 数学公式（`flutter_markdown_latex` + `flutter_math_fork`）
7. **EPUB 阅读器** `EpubReader`：基于 `epub_view` + `epubx`，支持章节导航与回流排版
8. **PDF 阅读器** `PdfReader`：基于 `pdfrx`，支持缩放、滚动、文字选择
9. **首页批量删除**：滑动单个移除、选择模式批量删除、全选/取消功能

### 待完成 ⏳

10. **标注系统**：高亮、划线、批注
11. **格式转换**：以 Markdown 为中继格式
12. **测试验证**：持续在 Windows / Android / iOS 运行验证

### 当前代码状态

- `flutter analyze` 已通过 ✅
- 依赖：`file_picker`, `flutter_markdown`, `path_provider`, `path`, `epub_view`, `pdfrx`, `flutter_markdown_latex`, `flutter_math_fork`, `fast_gbk`, `charset_converter`, `markdown`
- 注意：`flutter_markdown` 已被标记 discontinued，后续需迁移到 `flutter_markdown_plus`
- Windows 桌面端构建需开启系统开发者模式（插件 symlink 支持）

### 关键文件

- [lib/theme.dart](codes/palm_sugar_reader/lib/theme.dart) — 主题配置
- [lib/screens/home_screen.dart](codes/palm_sugar_reader/lib/screens/home_screen.dart) — 首页（含批量删除）
- [lib/screens/reader_screen.dart](codes/palm_sugar_reader/lib/screens/reader_screen.dart) — 阅读器壳
- [lib/readers/image_reader.dart](codes/palm_sugar_reader/lib/readers/image_reader.dart)
- [lib/readers/txt_reader.dart](codes/palm_sugar_reader/lib/readers/txt_reader.dart) — 多编码检测
- [lib/readers/markdown_reader.dart](codes/palm_sugar_reader/lib/readers/markdown_reader.dart) — 公式渲染
- [lib/readers/epub_reader.dart](codes/palm_sugar_reader/lib/readers/epub_reader.dart) — EPUB 阅读器
- [lib/readers/pdf_reader.dart](codes/palm_sugar_reader/lib/readers/pdf_reader.dart) — PDF 阅读器
- [notes/markdown-formula-support-2026-06-08.md](notes/markdown-formula-support-2026-06-08.md)
- [notes/txt-encoding-enhancement-2026-06-08.md](notes/txt-encoding-enhancement-2026-06-08.md)
- [notes/home-screen-batch-delete-2026-06-08.md](notes/home-screen-batch-delete-2026-06-08.md)

**Why:** 
- 用户希望功能拆分、做完一个测试一个。P0 的 5 种格式里图片/TXT/Markdown 是最简单的，先快速验证框架可行性；EPUB/PDF 需要引入第三方解析库，放在后面单独处理。
- 用户测试后反馈三点问题：Markdown 公式未渲染、TXT ANSI 乱码、首页缺少删除功能，均已逐一修复。

**How to apply:** 
- P0 多格式阅读核心代码已完成并通过 `flutter analyze`。Windows 端已成功运行验证。
- 后续可继续：标注系统、格式转换、Markdown 库迁移到 `flutter_markdown_plus`。

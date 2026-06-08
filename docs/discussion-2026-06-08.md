# 项目讨论留档 — 2026-06-08

> 参与者：用户（项目发起人）& AI 助手
> 主题：项目启动开发、主色调确认、P0 功能拆分策略

---

## 一、主色调确认

**用户决策**：程序主色调定为 `#A3C1AD`（鼠尾草绿 Sage Green）。

**已落实**：
- 已写入 [PRD.md](PRD.md) 设计决策记录第 5 条
- 已配置到 [lib/theme.dart](../codes/palm_sugar_reader/lib/theme.dart) 的完整 Material3 主题中

---

## 二、开发策略：功能拆分，逐个测试

**用户要求**：
- 功能拆成一个个来做，做完一个测试一个
- 先实现 P0 多格式阅读，做完后测试

**实际执行**：
- 先搭建基础框架（主题 + 文件选择 + 路由）
- 按难度从低到高逐个实现格式阅读器：
  1. 图片阅读器（最简单，先验证框架）
  2. TXT 阅读器（编码检测）
  3. Markdown 阅读器（flutter_markdown）
  4. EPUB 阅读器（待实现）
  5. PDF 阅读器（待实现）

---

## 三、P0 多格式阅读 — 实现进展

### 已完成 ✅

| 格式 | 阅读器 | 关键特性 |
|------|--------|----------|
| 图片 | `ImageReader` | 双指缩放、平移、双击放大 |
| TXT | `TxtReader` | 自动编码检测（UTF-8 → GBK fallback）、SelectableText |
| Markdown | `MarkdownReader` | flutter_markdown 渲染、自定义样式匹配主题色 |

### 待完成 ⏳

| 格式 | 计划方案 | 备注 |
|------|----------|------|
| EPUB | 待调研 `epub_view` 或替代库 | 需引入第三方解析依赖 |
| PDF | 待调研 `syncfusion_flutter_pdfviewer` | Windows 桌面端需跨平台支持 |

### 技术决策记录

- **状态管理**：MVP 阶段暂不引入 Provider/Riverpod/Bloc，先用 StatefulWidget 验证核心功能，后续重构时统一替换
- **Markdown 库选择**：当前使用 `flutter_markdown`，但已被标记 discontinued，后续需迁移到 `flutter_markdown_plus`
- **PDF 库考量**：Syncfusion 社区版是 Windows 桌面端唯一成熟的跨平台方案，虽包体积较大但功能完整

---

## 四、代码规范与质量

- `flutter analyze` 零错误 ✅
- 项目结构遵循 [AGENTS.md](../AGENTS.md)（snake_case 命名、文档归 docs/、代码归 codes/）
- 文件归属清晰：主题/模型/工具/页面/阅读器分层明确

---

## 四、P0 多格式阅读 — 完成 EPUB / PDF（同日追加）

### 已落实

| 格式 | 阅读器 | 库 | 关键特性 |
|------|--------|-----|----------|
| EPUB | `EpubReader` | `epub_view` + `epubx` | 章节导航、回流排版、图片内嵌 |
| PDF | `PdfReader` | `pdfrx` | 缩放、滚动、文字选择、页码导航 |

### 技术决策记录

- **EPUB 库**：选用 `epub_view: ^3.2.0`（纯 Flutter，跨平台），解析层依赖 `epubx: ^4.0.0`
- **PDF 库**：选用 `pdfrx: ^1.3.5`（基于 PDFium，Windows / Android / iOS / macOS / Linux / Web 全平台）
- **命名冲突**：`epubx` 的 `EpubReader` 与本项目的 `EpubReader` 类名冲突，通过 `import ... as epub_view` 前缀解决
- **flutter analyze**：零错误 ✅

### 环境注意事项

- Windows 桌面端构建需开启系统**开发者模式**，否则含原生插件的依赖（`pdfrx`、`file_picker`）会因 symlink 限制导致 `flutter pub get` / `flutter run` 失败
- Android / iOS 模拟器或真机不受此限制

---

## 五、用户反馈与优化（同日追加）

### 反馈来源

用户在 Windows 端成功运行并测试后，提出三点优化需求。

### 已处理 ✅

| # | 反馈 | 处理方案 | 文件 |
|---|------|----------|------|
| 1 | Markdown 内联公式没有渲染 | 引入 `flutter_markdown_latex` + `flutter_math_fork`，支持 `$...$`、`$$...$$`、 `\(...\)`、`\[...\]` 语法 | [markdown_reader.dart](../codes/palm_sugar_reader/lib/readers/markdown_reader.dart) |
| 2 | TXT 打开 ANSI 乱码，需要支持 JIS | 引入 `fast_gbk`（GBK/GB2312）和 `charset_converter`（Shift_JIS），编码检测优先级：UTF-8 → GBK → Shift_JIS → Latin1；界面显示检测到的编码 | [txt_reader.dart](../codes/palm_sugar_reader/lib/readers/txt_reader.dart) |
| 3 | 主界面加移除功能 + 批量删除 | 首页新增选择模式（长按/顶部按钮进入）、滑动单个删除、底部批量删除栏、全选/取消功能 | [home_screen.dart](../codes/palm_sugar_reader/lib/screens/home_screen.dart) |

### 新增依赖

- `flutter_markdown_latex: ^0.3.4` — Markdown LaTeX 扩展
- `flutter_math_fork: ^0.7.4` — 公式渲染引擎
- `fast_gbk: ^1.0.0` — GBK 编解码
- `charset_converter: ^2.4.0` — 平台原生编码转换（日文 Shift_JIS 等）
- `markdown: ^7.3.1` — 直接依赖（`flutter_markdown_latex` 需要）

### 质量检查

- `flutter analyze` 零错误 ✅

---

## 六、后续行动项

- [x] 调研并引入 EPUB 解析库
- [x] 调研并引入 PDF 渲染库
- [x] 实现 EPUB 阅读器
- [x] 实现 PDF 阅读器
- [x] Markdown 公式渲染
- [x] TXT 多编码支持
- [x] 首页批量删除
- [ ] 运行到 Windows / Android / iOS 设备整体测试 P0 功能
- [ ] 标注系统（高亮、划线、批注）
- [ ] 格式转换（MD 为中继）

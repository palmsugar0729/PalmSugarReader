---
name: bug-collection
description: PalmSugarReader 已知问题、Bug 与修复记录汇总
metadata:
  type: project
---

# PalmSugarReader Bug & 问题收集

> 本文档汇总开发过程中发现的问题、用户反馈的 Bug 及修复状态。
> 格式：`[状态] 问题描述 → 解决方案/备注`

---

## 🟢 已修复

### 1. Markdown 内联公式未渲染

- **发现时间**：2026-06-08（用户测试反馈）
- **现象**：Markdown 文档中的 `$E=mc^2$`、`$$...$$` 等 LaTeX 公式未正确渲染，直接显示原文
- **根因**：`flutter_markdown` 默认不支持数学公式语法
- **修复方案**：
  - 引入 `flutter_markdown_latex: ^0.3.4` + `flutter_math_fork: ^0.7.4`
  - 在 `MarkdownReader` 中配置 `LatexInlineSyntax`、`LatexBlockSyntax` 和 `LatexElementBuilder`
  - 支持语法：`$...$`、`$$...$$`、 `\(...\)`、`\[...\]`、 `\pu{...}`、`\ce{...}`、`[ ... ]`
- **相关文件**：[lib/readers/markdown_reader.dart](../../codes/palm_sugar_reader/lib/readers/markdown_reader.dart)
- **相关笔记**：[notes/markdown-formula-support-2026-06-08.md](../../notes/markdown-formula-support-2026-06-08.md)

### 2. TXT ANSI 编码文件乱码

- **发现时间**：2026-06-08（用户测试反馈）
- **现象**：中文 Windows 下生成的 ANSI 编码 TXT 文件打开后显示乱码
- **根因**：原有编码检测仅支持 UTF-8 → Latin1 fallback，无 GBK/Shift_JIS 支持
- **修复方案**：
  - 引入 `fast_gbk: ^1.0.0`（纯 Dart，同步 GBK 编解码）
  - 引入 `charset_converter: ^2.4.0`（平台原生编码转换，支持 Shift_JIS）
  - 检测优先级：UTF-8 → GBK → Shift_JIS → Latin1
  - 增加启发式校验（替换字符比例 < 5%）
  - 界面显示检测到的编码标签
- **相关文件**：[lib/readers/txt_reader.dart](../../codes/palm_sugar_reader/lib/readers/txt_reader.dart)
- **相关笔记**：[notes/txt-encoding-enhancement-2026-06-08.md](../../notes/txt-encoding-enhancement-2026-06-08.md)

### 3. `epubx` 的 `EpubReader` 类名冲突

- **发现时间**：2026-06-08（`flutter analyze` 报错）
- **现象**：`lib/readers/epub_reader.dart` 中调用 `EpubReader.readBook()` 时，Dart 解析器指向了当前文件定义的 `EpubReader` StatefulWidget，而非 `epubx` 包的 `EpubReader`
- **根因**：类名重复（当前 Widget 类名与第三方包类名相同）
- **修复方案**：对 `epub_view` 包使用前缀导入 `import 'package:epub_view/epub_view.dart' as epub_view;`
- **相关文件**：[lib/readers/epub_reader.dart](../../codes/palm_sugar_reader/lib/readers/epub_reader.dart)

---

## 🟡 已知问题 / 待优化

### 4. `flutter_markdown` 已标记 discontinued

- **发现时间**：2026-06-08
- **状态**：⚠️ 不影响功能，但官方推荐迁移
- **说明**：`flutter_markdown: ^0.7.7+1` 已被 pub.dev 标记为 discontinued，官方替代方案为 `flutter_markdown_plus`
- **影响**：当前配合 `flutter_markdown_latex` 使用正常，但长期建议迁移
- **计划**：P1 阶段评估迁移到 `flutter_markdown_plus`

### 5. 首页文件列表无持久化

- **发现时间**：2026-06-08
- **状态**：📋 设计如此（MVP 阶段），但用户可能期望重启后保留历史
- **说明**：`_recentBooks` 保存在内存中，应用重启后清空
- **计划**：后续引入 `shared_preferences` 或 SQLite 做本地持久化

---

## 🔴 环境问题（非代码 Bug）

### 6. Windows 桌面端构建需开发者模式

- **发现时间**：2026-06-08
- **现象**：`flutter pub get` 报错 "Building with plugins requires symlink support"
- **根因**：含原生插件的包（`pdfrx`、`file_picker`）在 Windows 上构建需要创建符号链接
- **解决**：开启 Windows 系统设置中的「开发者模式」
- **操作**：运行 `start ms-settings:developers` 或在「设置 → 隐私和安全性 → 开发者模式」中开启

### 7. Windows 桌面端构建需 Visual Studio C++ 工具链

- **发现时间**：2026-06-08
- **现象**：`flutter run -d windows` 报错 "Unable to find suitable Visual Studio toolchain"
- **根因**：未安装 Visual Studio 的 C++ 桌面开发工作负载
- **解决**：
  1. 安装 Visual Studio Community（免费）或 Build Tools
  2. 在 Visual Studio Installer 中勾选 **「使用 C++ 的桌面开发」** 工作负载
  3. 重新运行 `flutter run -d windows`

---

## 📝 反馈模板

发现新 Bug 时请按以下格式记录：

```markdown
### 编号. 问题标题

- **发现时间**：YYYY-MM-DD
- **报告人**：@用户名
- **现象**：
- **复现步骤**：
  1. ...
  2. ...
- **期望行为**：
- **实际行为**：
- **环境**：Windows / Android / iOS + Flutter 版本
- **相关文件**：
- **状态**：待修复 / 已修复 / 已知问题
```

# PalmSugarReader 🍬

> 轻量、友好的跨平台综合阅读器 —— 阅读、标注、格式转换，一个就够了。

[![Flutter](https://img.shields.io/badge/Flutter-3.44.1-blue.svg)](https://flutter.dev)
[![Platforms](https://img.shields.io/badge/Platforms-Windows%20%7C%20Android%20%7C%20iOS-green.svg)]()

## 这是什么

PalmSugarReader 是一个支持多种文档格式的跨平台阅读器，覆盖 **Windows、Android、iOS** 三端。专注**阅读 + 标注**，不做臃肿的编辑功能，保持轻量与友好。

## 当前进度

### ✅ 已完成

| 功能 | 说明 |
|------|------|
| PDF 阅读 | `pdfrx`，缩放(+/-/Ctrl+滚轮/滑条)、标注图层、键盘 ↑↓/PgUp/PgDn/Home/End/Space/Shift+Space |
| EPUB 阅读 | 自研翻页阅读器（`epubx` + `PageView`），懒加载秒开，←→/Home/End/Space 翻页，退出进度恢复 |
| TXT 阅读 | 多编码自动检测 + 全局字号联动 + 键盘 ↑↓/PgUp/PgDn/Home/End/Space |
| Markdown 阅读 | LaTeX 数学公式 + 全局字号联动 + 键盘 ↑↓/PgUp/PgDn/Home/End/Space |
| 图片阅读 | `InteractiveViewer` 缩放/平移 + 标注图层 + 键盘 +/-/0 |
| 标注系统 | 统一 `AnnotationLayer`：高亮/划线 + 批注便签 + 自-由画笔（铅笔/画笔/水彩笔） + 橡皮擦 + 撤销 |
| 平板工具栏 | GoodNotes 风格浮动工具栏 — 即时切换工具/颜色/粗细，可折叠，防误触（仅响应触控笔） |
| 书签管理 | 手动书签（添加/列表/跳转/删除），per-file JSON 持久化，支持 PDF/EPUB |
| 格式转换 | TXT ↔ MD、EPUB → MD、MD → PDF、MD → EPUB、MD → TXT、图片 → PDF |
| 主题系统 | Material3 `#A3C1AD` + 暗色主题 + 跟随系统 |
| 设置页面 | 批量导入、字号三档(14/18/24)、背景色、字体导入、帮助、清除历史 |
| 顶部菜单栏 | 鼠标悬停展开，标注/书签/转换/背景色/设置 |
| 最近文件 | JSON 进度记忆 + 重启恢复 |
| 批量导入 | 同目录同扩展名+词干匹配 |
| 文件拖拽 | 从系统拖入文件直接打开（支持格式）或警告（不支持格式） |

### 🚧 待开发

| 功能 | 优先级 |
|------|--------|
| 用户系统 & 云同步 | P2 |
| AI 学习增强 | P2 |

## 技术栈

| 层 | 选型 |
|---|------|
| 框架 | Flutter（MVP 阶段三端统一） |
| 桌面备选 | Tauri + Flutter（后期若体积过大） |
| 语言 | Dart |
| 状态管理 | StatefulWidget（MVP 阶段），后续迁移 Provider/Riverpod/Bloc |

## 如何运行

### 环境要求

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.44.1
- **Windows 桌面端**：Visual Studio + "使用 C++ 的桌面开发" 工作负载 + 系统开发者模式
- **Android**：Android SDK + 模拟器或真机
- **iOS**：Xcode（仅 macOS）

### 快速开始

```bash
# 1. 进入项目目录
cd codes/palm_sugar_reader

# 2. 安装依赖
flutter pub get

# 3. 运行到 Windows
flutter run -d windows

# 4. 或运行到 Android 模拟器
flutter run -d emulator-5554
```

## 项目结构

```
PalmSugarReader/
├── docs/                  # 产品文档、需求、讨论留档、Bug 收集
│   ├── PRD.md
│   ├── discussion-*.md
│   └── bugs/
├── assets/                # 设计与参考素材
│   ├── design/
│   ├── bug/
│   └── reference/
├── notes/                 # 开发笔记与踩坑记录
├── codes/                 # 源代码（Flutter 项目）
│   └── palm_sugar_reader/
│       ├── lib/
│       │   ├── main.dart
│       │   ├── theme.dart
│       │   ├── models/
│       │   ├── screens/
│       │   ├── readers/
│       │   └── utils/
│       ├── pubspec.yaml
│       └── ...
├── AGENTS.md              # AI 开发指引
└── README.md              # 本文件
```

## 主色调

**鼠尾草绿 Sage Green** `#A3C1AD`

传递轻量、自然、友好的产品气质。

## 相关文档

- [AGENTS.md](AGENTS.md) — AI 开发指引与代码规范
- [docs/PRD.md](docs/PRD.md) — 产品需求文档（唯一真相源）
- [docs/discussion-2026-06-21.md](docs/discussion-2026-06-21.md) — 最新开发讨论留档
- [docs/implementation-plan-annotation-toolbar.md](docs/implementation-plan-annotation-toolbar.md) — 标注工具栏实施计划
- [notes/](notes/) — 技术决策与踩坑记录

## 贡献与反馈

欢迎提交 Issue 或 PR。

## 许可

待定

# PalmSugarReader 🍬

> 轻量、友好的跨平台综合阅读器 —— 阅读、标注、格式转换，一个就够了。

[![Flutter](https://img.shields.io/badge/Flutter-3.44.1-blue.svg)](https://flutter.dev)
[![Platforms](https://img.shields.io/badge/Platforms-Windows%20%7C%20Android%20%7C%20iOS-green.svg)]()

## 这是什么

PalmSugarReader 是一个支持多种文档格式的跨平台阅读器，覆盖 **Windows、Android、iOS** 三端。专注**阅读 + 标注**，不做臃肿的编辑功能，保持轻量与友好。

## 当前进度

### ✅ 已完成（P0 多格式阅读）

| 功能 | 状态 | 说明 |
|------|------|------|
| PDF 阅读 | ✅ | 基于 `pdfrx`，支持缩放、滚动、文字选择 |
| EPUB 阅读 | ✅ | 基于 `epub_view`，支持章节导航、回流排版 |
| TXT 阅读 | ✅ | 自动编码检测（UTF-8 → GBK → Shift_JIS → Latin1） |
| Markdown 阅读 | ✅ | 基于 `flutter_markdown`，支持 LaTeX 数学公式 |
| 图片阅读 | ✅ | 支持双指缩放、平移、双击放大 |
| 主题系统 | ✅ | Material3 + 鼠尾草绿 `#A3C1AD` |
| 首页批量删除 | ✅ | 滑动删除 + 选择模式批量移除 |

### 🚧 待开发

| 功能 | 优先级 |
|------|--------|
| 标注系统（高亮、划线、批注） | P0 |
| 书签与阅读进度持久化 | P0 |
| 格式转换（MD 为中继） | P1 |
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
- [docs/discussion-2026-06-08.md](docs/discussion-2026-06-08.md) — 最新开发讨论留档
- [notes/](notes/) — 技术决策与踩坑记录

## 贡献与反馈

欢迎提交 Issue 或 PR。

## 许可

待定

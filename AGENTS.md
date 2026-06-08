# PalmSugarReader — AI 开发指引

## 项目概述

PalmSugarReader 是一个跨平台综合阅读器，支持 PDF、EPUB、TXT、MD 等主流文档格式的阅读与标注。MVP 阶段使用 Flutter 三端统一开发（Windows / Android / iOS），未来可扩展用户系统、内容商城与 AI 学习增强功能。

## 文件夹结构

```
PalmSugarReader/
├── docs/                  # 📄 产品文档
│   ├── PRD.md             #   产品需求文档（唯一真相源）
│   └── discussion-*.md    #   历史讨论留档
├── assets/
│   ├── design/            # 🎨 设计素材：效果图、UI 参考、原型图
│   ├── bug/               # 🐛 测试报错截图、复现记录
│   └── reference/         # 📸 参考图、灵感收集、竞品截图
├── notes/                 # 📝 学习笔记：踩坑记录、技术方案、决策理由
├── codes/                 # 💻 所有源代码
│   └── palm_sugar_reader/ #   Flutter 主项目（flutter create 产出）
└── AGENTS.md              # 本文件
```

## 开发规则

### 文件归属
- 所有产品文档（PRD、需求迭代、决策记录）**必须**放在 `docs/` 下，根目录不得残留 `.md` 需求文件
- 设计稿、UI 截图放 `assets/design/`，Bug 截图放 `assets/bug/`，灵感参考放 `assets/reference/`
- 开发中遇到的技术问题、方案对比、坑点记录放 `notes/`，文件名建议格式：`主题-日期.md`

### 代码区规则
- `codes/` 为独立代码区，**不引用** `codes/` 外部的文件（如图片、配置）
- 代码所需的静态资源随 Flutter 项目的 `assets/` 目录管理，**不**使用根目录 `assets/`
- Flutter 项目目录名使用 snake_case：`palm_sugar_reader`
- 提交代码前确保 `flutter analyze` 无 error

### 文档写作规范
- PRD.md 是唯一需求真相源，需求变更时更新 PRD.md 并在 `docs/` 留讨论留档
- 每次重大讨论后，在 `docs/` 留一份 `discussion-YYYY-MM-DD.md` 存档
- README.md 面向人类开发者，AGENTS.md 面向后续 AI 开发者

### 技术约束
- MVP 阶段：Flutter 一套代码三端（Windows / Android / iOS）
- 状态管理：后续确定（Provider / Riverpod / Bloc 选一）
- 格式解析：优先 PDF、EPUB、TXT、MD、图片；随后 MOBI、DOCX
- 编辑范围：**仅标注**（高亮、划线、批注），不修改原文
- 轻量化原则：避免引入重依赖，能用 Platform Channel 的不加 Plugin

### 命名约定
- Dart 文件名：snake_case（`book_reader.dart`）
- 类名：PascalCase（`BookReader`）
- 变量/函数：camelCase（`openBook`）
- 常量：camelCase 或 SCREAMING_SNAKE_CASE（视上下文）

## 当前状态

- [x] 需求文档（PRD.md）
- [x] Flutter 项目初始化
- [x] P0 格式解析与阅读器（PDF / EPUB / TXT / MD / 图片）
- [x] 阅读器核心 UI（首页 + 路由壳 + 5 种格式阅读器）
- [ ] 标注系统
- [ ] 格式转换

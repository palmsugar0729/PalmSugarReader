---
name: markdown-formula-support
description: Markdown 阅读器 LaTeX 公式渲染方案记录
metadata:
  type: project
---

## 需求

用户反馈 Markdown 文档中的内联公式（如 `$E=mc^2$`）没有正确渲染。

## 方案对比

| 方案 | 优点 | 缺点 |
|------|------|------|
| `flutter_markdown_latex` | 与现有 `flutter_markdown` 无缝集成，支持多种公式语法 | 依赖 `flutter_math_fork`，增加包体积 |
| 自己写正则 + `flutter_math_fork` | 灵活可控 | 维护成本高，边界情况多 |
| 换用 `markdown_widget` | 社区方案成熟 | 需重写现有 MarkdownReader，改动大 |

## 最终决策

采用 **`flutter_markdown_latex` + `flutter_math_fork`**。

- `flutter_markdown_latex` 提供 `LatexInlineSyntax`、`LatexBlockSyntax` 和 `LatexElementBuilder`
- `flutter_math_fork` 负责纯 Flutter 渲染，不依赖 WebView

## 支持的语法

- 行内：`$...$`、`\(...\)`、`\pu{...}`、`\ce{...}`
- 块级：`$$...$$`、`\[...\]`、`[ ... ]`

## 代码要点

```dart
Markdown(
  extensionSet: md.ExtensionSet.gitHubFlavored,
  builders: {'latex': LatexElementBuilder(textStyle: ...)},
  inlineSyntaxes: [LatexInlineSyntax()],
  blockSyntaxes: [LatexBlockSyntax()],
)
```

**Why:** 改动最小，与现有 `flutter_markdown` 主题样式兼容。

**How to apply:** 如需添加更多公式语法（如 AsciiMath），可扩展 `LatexInlineSyntax` 的 `delimiterList`。

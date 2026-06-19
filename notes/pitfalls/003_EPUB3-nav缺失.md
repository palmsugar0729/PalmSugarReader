---
date: 2026-06-19
tags: [pitfall, epub, epub3, archive, xml]
project: PalmSugarReader
status: resolved
aliases: ["EPUB 缺少 nav.xhtml 导致打不开"]
---

# EPUB 缺少 nav.xhtml 导致阅读器无法打开

**状态**：🟢 已解决
**发现日期**：2026-06-19
**关联**：[[2026-06-19_开发日志]] · [[手写EPUB3结构]]

## 现象

MD to EPUB 转换成功，文件大小正常，但用阅读器（Apple Books、多看、微信读书）打开时显示空白或报错"无法打开"。

## 根因

第一版实现只写了 EPUB 2 的结构：

- `mimetype`
- `META-INF/container.xml`
- `OEBPS/content.opf`（version="2.0"）
- `OEBPS/toc.ncx`
- `OEBPS/text/chapter*.xhtml`

**缺少 EPUB 3 必须的 `nav.xhtml`**。

EPUB 3 规范要求每个 EPUB 必须包含一个带有 `properties="nav"` 的导航文档。没有它的 EPUB 在现代阅读器眼中是不合规的，直接拒绝解析。

## 解决方案

### 1. 添加 `OEBPS/nav.xhtml`

```xml
<nav epub:type="toc" id="toc">
  <ol>
    <li><a href="text/chapter1.xhtml">第一章</a></li>
    <li><a href="text/chapter2.xhtml">第二章</a></li>
  </ol>
</nav>
```

### 2. `content.opf` 版本升级为 `3.0`

```xml
<package version="3.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="bookid">
```

### 3. manifest 中声明 nav

```xml
<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
```

### 4. 内嵌 CSS

```css
body { font-family: sans-serif; line-height: 1.8; }
p { text-indent: 2em; }
blockquote { border-left: 4px solid #4caf50; }
```

参考了 Python 项目 `easy_EPUB_generator` 的 CSS 结构和封面页概念。

## 预防

- [ ] 手写 EPUB 时，对照 EPUB 3 规范检查必需文件清单
- [ ] EPUB 2 vs EPUB 3 差异表：版本号、nav 文档、properties 属性、HTML5 vs XHTML

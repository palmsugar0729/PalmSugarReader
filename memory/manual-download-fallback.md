---
name: manual-download-fallback
description: 当构建过程中某个依赖需要下载外部二进制文件但网络不通时，交给人手动下载
metadata:
  type: feedback
---

# 手动下载回退模式

当构建过程中某个包需要从外网下载二进制文件（GitHub Releases 等）但网络不通时，让人手动下载，然后放到指定缓存目录。

## 识别信号

- 构建日志中出现 `file(DOWNLOAD https://github.com/...)` 或 `CMake` 下载步骤
- 错误：`Could not obtain PDFium binary` / `Connection reset` / 超时
- 缓存目录中出现 0 字节或大小不变的 `.tgz` / `.zip` 文件

## 处理流程

1. 定位下载 URL（通常在包的 `CMakeLists.txt` 中）
2. 告知用户：文件大小、下载链接
3. 用户下载后放到指定位置
4. 手动解压到包的缓存目录（两个位置）：
   - `.lib/` — 永久缓存
   - `.cxx/Debug/<hash>/` — 构建临时目录（hash 是确定性的，不变）

## 已遇到的案例

- **pdfrx**：需要 PDFium 二进制 → [[pdfium-download]] 记录具体路径
- `desktop_drop`：不是下载问题，是 compileSdk 版本冲突 → 直接移除（Android 不需要）

**Why:** 国内访问 GitHub Releases 极不稳定（~5KB/s，频繁超时），人力下载 6MB 文件只需几秒
**How to apply:** 遇到 `file(DOWNLOAD ...)` 超时 → 找到 URL → 让用户下载 → 解压到缓存

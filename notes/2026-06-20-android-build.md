---
date: 2026-06-20
tags:
  - learning
  - android
  - flutter
  - gradle
  - pdf
---

# Android 构建踩坑记录

> PalmSugarReader 首次 Android APK 构建全程记录

## 1. Gradle 配置

### Gradle 镜像
国内下载 Gradle 极慢（~5KB/s），改用腾讯云镜像：
```properties
distributionUrl=https\://mirrors.cloud.tencent.com/gradle/gradle-9.1.0-all.zip
```

### Maven 镜像
`build.gradle.kts` 添加阿里云 + 腾讯云镜像仓库在 `google()` / `mavenCentral()` 之前。

### Kotlin 增量编译跨盘符
pub cache (C:) 和项目 (D:) 不同盘符，Kotlin 增量编译报错。解决：
```properties
kotlin.incremental=false
```

### compileSdk 版本
Flutter 默认 compileSdk 33，但 `file_picker` 等插件依赖需要 34+。手动设为 36：
```kotlin
compileSdk = 36
```

## 2. PDF 支持 — pdfrx

### 问题
`pdfrx` 的 CMake 构建需要从 GitHub Releases 下载 PDFium 预编译二进制（~2.6MB Android / ~5MB Windows）。国内网络频繁超时。

### 解决：手动下载回退
1. 从 GitHub 下载 `pdfium-android-arm64.tgz` / `pdfium-win-x64.tgz`
2. 解压到两处：
   - `.lib/chromium%2F7202/<abi>/` — 永久缓存（pub cache）
   - `.cxx/Debug/<hash>/<abi>/pdfium/chromium%2F7202/` — 构建临时目录
3. CMake 检测到 `.so`/`.dll` 已存在 → 跳过下载

详见 [[manual-download-fallback]]

### 文件锁
CMake 下载失败后产生的 0 字节 `.tgz` 可能被系统进程锁定（`Device or resource busy`），必须重启释放。

## 3. 移除的依赖

- **`desktop_drop`** — 桌面端文件拖拽，Android 不需要，且插件 compileSdk 写死 33 与新版 AndroidX 冲突。直接移除依赖。

## 4. 平台分离菜单

移动端不能复用桌面端的独立 bar 布局。最终方案：
- 移动端：菜单图标放入 `AppBar.actions`
- 桌面端：保持 `MouseRegion` hover 滑出

详见 [[platform-menu-pattern]]

## 5. 最终构建时间

| 构建 | 时间 |
|------|------|
| 首次（含 Gradle 下载） | ~15 min |
| 无 PDFium 编译 | ~40s |
| 含 PDFium C++ 编译 | ~16 min |

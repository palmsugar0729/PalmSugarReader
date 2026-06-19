# end-session-and-archive

当用户表示要结束当前会话时，按以下顺序**逐项执行，不得跳过**。

## 触发条件

用户说出以下任意表达时自动触发：
- "今天就到这里" / "今天就告一段落" / "先这样吧"
- "明天继续" / "晚点再继续" / "下次再说"
- "结束" / "先休息" / "差不多了"

## 执行流程（全部必做，不可跳过）

按顺序执行以下 9 步，每步完成后再做下一步。用 TodoWrite 跟踪进度。

### Step 1: 更新开发日志

**文件**：`notes/YYYY-MM-DD_开发日志.md`（按日期查找）

1. 读取文件
2. 在末尾追加（或更新当天已有条目）：
   - 今日完成的所有事项（列表形式）
   - 关键决策及原因
   - 修改/新增的文件清单
   - 下一步计划

**要求**：必须写具体，不要空洞的"修复了若干 bug"，要列出具体修复了什么。

### Step 2: 更新 PRD

**文件**：`docs/PRD.md`

1. 检查当天是否有新增功能或完成已有功能的开发
2. 将已完成的功能条目打勾 `[x]`
3. 如有新的关键决策，追加到「关键决策记录」表格
4. 如果 PRD 没有变更，至少检查确认，不要跳过

### Step 3: 更新 README

**文件**：`README.md`

1. 检查功能概览部分是否反映当前最新状态
2. 新功能描述必须和实际实现一致
3. 如有项目结构变化（新增目录/文件），更新结构说明
4. 如果 README 没有变更，至少检查确认，不要跳过

### Step 4: 更新 MEMORY.md

**文件**：根目录 `MEMORY.md`

1. 检查本次会话中有无值得持久记忆的内容（用户偏好、设计决策、代码模式）
2. 如有，确保 `memory/` 目录下的对应文件已更新
3. `MEMORY.md` 索引是否包含所有 memory 文件的链接

### Step 5: Git 提交 + 推送

```bash
cd {项目根目录}
git add -A
git status              # 先看变更范围
git commit -m "..."     # 根据变更内容写有意义的 commit message
git push
```

- commit message 格式：`feat: xxx`（新功能）、`fix: xxx`（修 bug）、`docs: xxx`（纯文档）、`chore: xxx`（杂项）
- 如果工作区干净（无变更），跳过 commit 但**必须 git push 确认远程已同步**
- 除非用户明确说过"不要 push"，否则必须 push

### Step 6: 同步到 Obsidian

调用 obsidian-sync skill，将以下文件同步到 Obsidian Vault：
1. `notes/YYYY-MM-DD_开发日志.md` → DevLogs/
2. `docs/bugs/*.md` → Pitfalls/（新增的 bug 文档）
3. `docs/PRD.md` → 项目文档/
4. `memory/*.md` → 项目文档/

### Step 7: 保存对话存档

**文件**：`docs/discussion-YYYY-MM-DD{_ampm}.md`

1. 检查当天是否已有讨论存档，如有则创建下午/晚间版（加 `-afternoon` 后缀）
2. 内容模板：
   - 主题概述
   - 各项功能开发的关键决策和原因
   - Bug 修复的根因和方案
   - 技术笔记（新发现的模式、API 对比等）
   - 修改/新增文件清单
3. 参考格式：[docs/discussion-2026-06-19.md](docs/discussion-2026-06-19.md)

### Step 8: 整理 Bug

**文件**：`docs/bugs/bug-collection.md`

1. 本次会话发现和修复的 bug 追加到对应区域（🟢 已修复 / 🟡 待优化）
2. 按模板格式：发现时间、现象、根因、修复方案、相关文件
3. 如截了图，关联 `assets/bug/` 中的截图路径

### Step 9: 整理学习笔记

**目录**：`notes/learnings/`

1. 从本次会话提炼 1-3 个技术学习点，写入独立 `.md` 文件
2. 格式：Obsidian YAML frontmatter + 背景 + 核心内容 + 代码模板 + 相关文件链接
3. 主题示例：
   - 新 API 的使用模式和踩坑（如 `HardwareKeyboard` vs `Focus.onKeyEvent`）
   - 设计模式/架构决策（如内存优先数据流）
   - 第三方库使用技巧
4. 参考格式：[notes/learnings/](notes/learnings/)

## 注意事项

- **不要问用户"要不要做"**——每步直接执行，做完报告结果
- **不要半途而废**——9 步必须全部跑完，中间报错就修复后继续
- 对话记录不需要完整的代码 diff，只需要文件路径和修改概要
- 如果某一步确实没有变更内容，仍然要**检查确认**后跳过，并说明"无需变更"
- commit message 用中文写概要，让用户看得懂

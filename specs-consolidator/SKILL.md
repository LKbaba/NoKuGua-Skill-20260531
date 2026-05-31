---
name: specs-consolidator
description: This skill should be used when the user asks to "整合 PRD 文档", "合并 updatePRD", "consolidate PRD updates", "整理版本文档", "清理 updatePRDv*". 自动整合多个版本的 PRD 更新文档到 consolidated 文档，并同步更新主 PRD.md 和 AGENTS.md。updatePRD 文件总是从 v1 开始编号为新一批，版本映射规则是延续 consolidated 文档的主版本号递增（如 consolidated 当前 v5.10，则下一批映射为 v6.1~v6.N）。整合前应使用 Codex 的文件搜索和 targeted read 充分理解每个文档的详细内容。
version: 2.0.0
author: Codex
---

# Specs Consolidator - 文档整合工具

自动化整合多个版本的 PRD 更新文档（updatePRDvx.md）到一个 consolidated 文档中，并同步更新主 PRD.md 和 AGENTS.md。

## 何时使用

当项目积累了多个版本的 updatePRD 文档（如 updatePRDv1.md, updatePRDv2.md 等），需要：
- 整合到一个统一的 consolidated 文档
- 更新主 PRD.md 的版本号和历史记录
- 同步技术细节到 AGENTS.md
- 清理已整合的旧文档

## 工作流程

### 阶段 0：Codex 深度阅读（推荐）

整合前，使用 `rg`/`rg --files` 扫描候选文件，并对所有待整合的 updatePRD 文件进行 targeted read。这一步很重要，因为：
- updatePRD 文件内部的版本号（如 v9.0、v10.0）**不是**映射目标版本号
- 需要理解每个文档的实际功能和状态，才能正确分类和整合
- 避免遗漏关键技术细节和踩坑记录

### 阶段 1：分析现状

1. **扫描 specs/ 目录**，识别所有 updatePRDv*.md 文件和对应的 PLAN 文件
2. **读取 updatePRD-consolidated.md**，确定当前版本号（如 v5.10）
3. **确定版本号映射**：按下方「版本号映射规则」自动计算

### 阶段 2：整合文档

1. **读取所有新版本文档**，提取关键内容
2. **按功能模块组织**，而非按版本号堆叠
3. **更新 consolidated 文档**：
   - 更新版本号和日期
   - 更新版本演进时间线表格
   - 按章节整合新内容
   - 更新技术债务清单

参考 `references/consolidation-template.md` 了解文档结构。

### 阶段 3：同步主文档

1. **更新 PRD.md**：
   - 版本号和日期
   - 版本演进历史表格
   - 技术债务和已知问题
   - 后续规划

2. **更新 AGENTS.md**：
   - 项目概述中的版本号
   - 关键技术细节章节
   - 新增的踩坑记录

### 阶段 4：清理旧文档

1. **使用 git rm 删除**已整合的 updatePRDv*.md 文件
2. **保留 Git 历史**，确保可追溯
3. **创建整理报告**，记录清理的文件和原因
4. **提交变更**，使用规范的 commit message

参考 `references/cleanup-checklist.md` 了解清理标准。

## 版本号映射规则（核心规则，务必遵守）

updatePRD 文件的编号（v1, v2, v3...）是**每一批的序号**，不是系统版本号。每次整合时，这些序号需要映射为 consolidated 文档的连续版本号。

### 映射算法

1. 读取 `updatePRD-consolidated.md` 的当前版本号（如 `v5.10`）
2. 取主版本号并加 1，作为新一批的主版本（如 `5` → `6`）
3. 每个 updatePRD 文件按序号映射：`updatePRDvN.md` → `v{主版本}.{N}`

### 映射公式

```
新版本号 = v{consolidated主版本 + 1}.{updatePRD序号}
```

### 历史映射记录

| 批次 | consolidated 起始版本 | updatePRD 范围 | 映射结果 |
|------|---------------------|---------------|----------|
| 第 1 批 | v3.10 | updatePRDv1~v8 | v4.1~v4.8（注：实际从 v4.3 开始） |
| 第 2 批 | v4.8 | updatePRDv1~v10 | v5.1~v5.10 |
| 第 3 批 | v5.10 | updatePRDv1~vN | v6.1~v6.N |

### 常见误区

**错误做法**：把 updatePRD 文件内部的版本号（如 `v9.0`、`v10.0`）直接当作映射目标。
文件内部版本号是该 PRD 文档自己的迭代版本（如 v9.0→v9.1→v9.1.1），与 consolidated 的版本号体系无关。

**正确做法**：忽略文件内部版本号，统一按 `updatePRDv{N}` 的 N 来映射。

## 文档结构标准

### Consolidated 文档结构

```markdown
# 消息中台 - 功能更新汇总文档

> **版本**: vX.Y (整合版)
> **日期**: YYYY-MM-DD
> **状态**: 已部署
> **基于**: PRD.md vX.Y

## 目录
1. 版本演进概览
2. 基础功能与界面优化
3. [按功能模块组织]
...

## 一、版本演进概览

### 1.1 完整版本时间线

| 版本 | 日期 | 主要功能 | 状态 |
|------|------|----------|------|
...

### 1.2 功能模块完成度
...
```

### Commit Message 模板

```
docs: 整合 vX.Y~vX.Z 功能更新到 consolidated 文档

## 主要变更

### 文档整合
- 整合 updatePRDvA~vB 到 updatePRD-consolidated.md (vX.Y → vX.Z)
- 新增 N 行内容，涵盖 M 个版本的功能更新
- 新增章节：[列出新章节]

### 版本号调整
- vA → vX.A ([简要说明])
- vB → vX.B ([简要说明])
...

### PRD.md 更新
- 版本号：vX.Y → vX.Z
- 更新版本演进历史表格
- 更新技术债务清单

### AGENTS.md 更新
- 新增 [技术细节]
- 更新项目概述版本号

### 文件清理
- 删除已整合的 updatePRDvA~vB.md (N 个文件)
- 保留 Git 历史记录

Generated with Codex.
```

## 使用示例

### 示例 1：整合第 2 批 updatePRD（v5.1~v5.10）

```
用户: "帮我整合 updatePRD 文档"

执行流程:
1. 【阶段 0】用 `rg` 扫描候选文件，并逐个读取所有 updatePRDv1~v10.md 的完整内容
2. 【阶段 1】扫描 specs/ 目录，发现 updatePRDv1~v10.md
3. 读取 consolidated.md，当前版本 v4.8
4. 计算映射：主版本 4+1=5，所以 v1→v5.1, v2→v5.2, ..., v10→v5.10
5. 【阶段 2】整合内容到 consolidated.md（v4.8 → v5.10）
6. 【阶段 3】更新 PRD.md 和 AGENTS.md
7. 【阶段 4】git rm 删除 updatePRDv1~v10.md 及 PLAN 文件
8. 提交变更
```

### 示例 2：整合第 3 批 updatePRD（v6.1~v6.N）

```
用户: "帮我整理 updatePRD 文档"

执行流程:
1. 读取 consolidated.md，当前版本 v5.10
2. 扫描发现 updatePRDv1~v5.md（5 个新文件）
3. 计算映射：主版本 5+1=6，所以 v1→v6.1, v2→v6.2, ..., v5→v6.5
4. 整合到 consolidated.md（v5.10 → v6.5）
5. 更新 PRD.md 和 AGENTS.md
6. 清理旧文件并提交
```

### 示例 3：只整合特定版本

```
用户: "只整合 v5 和 v6 的更新"

执行流程:
1. 读取 consolidated.md 当前版本（如 v5.10）
2. 只读取 updatePRDv5.md 和 v6.md
3. 映射：v5→v6.5, v6→v6.6
4. 整合到 consolidated.md
5. 更新主文档，删除这两个文件
```

## 质量检查清单

整合完成后，验证以下内容：

- [ ] consolidated.md 版本号已更新
- [ ] 版本演进时间线表格完整
- [ ] 所有新功能都有对应章节
- [ ] PRD.md 版本号和历史表格已更新
- [ ] AGENTS.md 技术细节已同步
- [ ] 旧文档已删除（git rm）
- [ ] Commit message 符合模板
- [ ] 所有变更已推送到远程

## 注意事项

1. **版本号一致性**：确保 consolidated、PRD、AGENTS.md 三个文档的版本号一致
2. **内容去重**：整合时避免重复内容，按功能模块合并
3. **保留历史**：使用 `git rm` 而非直接删除，保留 Git 历史
4. **标记状态**：在版本表格中标记每个版本的状态（✅已完成 / ⏸️待实施）
5. **技术债务**：更新时标记已解决的技术债务为删除线

## 相关资源

- **`references/consolidation-template.md`** - Consolidated 文档模板
- **`references/cleanup-checklist.md`** - 文档清理检查清单
- **`references/version-mapping-guide.md`** - 版本号映射指南
- **`scripts/analyze-specs-versions.sh`** - 版本分析脚本
- **`examples/consolidation-example.md`** - 完整整合示例

---

*Skill adapted for Codex*
*Last updated: 2026-05-31*

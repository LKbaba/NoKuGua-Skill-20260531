# PRD 文档整合完整示例

本示例展示了如何将 updatePRDv3~v8 整合到 v4.8 的完整过程。

## 背景

- **当前版本**：v3.10（2026-02-14）
- **待整合文档**：updatePRDv3.md ~ updatePRDv8.md（6个文件）
- **目标版本**：v4.8
- **项目**：802 客服系统 - 消息中台

## 阶段 1：分析现状

### 1.1 扫描文档

```bash
$ bash scripts/analyze-specs-versions.sh

=== PRD 版本分析工具 ===

## 1. 扫描 updatePRD 文件

📄 找到以下 updatePRD 文件：
  - specs/updatePRDv3.md (11KB)
  - specs/updatePRDv4.md (6.4KB)
  - specs/updatePRDv5.md (12KB)
  - specs/updatePRDv6.md (8.7KB)
  - specs/updatePRDv7.md (13KB)
  - specs/updatePRDv8.md (12KB)

📋 找到以下 PLAN 文件：
  - specs/updatePRDv3-PLAN.md
  - specs/updatePRDv4-PLAN.md
  - ...

## 2. Consolidated 文档状态

📚 当前版本：v3.10
📅 更新日期：2026-02-14

## 3. 版本号分析

建议的版本号映射：

| 原文件 | 建议版本 | 说明 |
|--------|---------|------|
| updatePRDv3.md | v4.3 | Settings 页面改造 + 意图识别增强 |
| updatePRDv4.md | v4.4 | 固定回复功能 |
| updatePRDv5.md | v4.5 | 意图识别精度优化 + 事件面板增强 |
| updatePRDv6.md | v4.6 | 客户名称 + 语音消息对齐 |
| updatePRDv7.md | v4.7 | 系统查漏补缺（7个P0/P1修复） |
| updatePRDv8.md | v4.8 | 稳定性修复（Token竞态 + check1去重） |

🎯 目标版本：v4.8
```

### 1.2 确认版本映射

基于分析结果，确认版本号映射关系：

- v3 → v4.3：重大 UI 改造，升级主版本
- v4~v8 → v4.4~v4.8：连续递增

## 阶段 2：整合文档

### 2.1 读取所有文档

依次读取 updatePRDv3~v8.md，提取关键内容：

**v4.3 (updatePRDv3)**：
- Settings 页面 Tab 顺序调整
- 意图识别加入对话上下文
- 支持推理模式开关
- DeepSeek 超时从 10s 调到 60s

**v4.4 (updatePRDv4)**：
- 固定回复功能
- 节假日歇业场景
- 变量替换 `{staffPhone}`

**v4.5 (updatePRDv5)**：
- 修复降级函数 isHighPriority Bug
- DeepSeek 超时从 10s 调到 60s
- 事件面板点击查看聊天记录
- 意图识别详情持久化

**v4.6 (updatePRDv6)**：
- 客户名称用 chat_name 同步
- 语音消息转写显示
- 语音消息纳入意图识别

**v4.7 (updatePRDv7)**：
- 防重复发送（先标记再发送）
- n8n 连续失败熔断
- hasStaffReplied 排除 AI
- msgId 改用 UUID
- 降级话术补全
- Dashboard 统计指标
- 配置批量保存

**v4.8 (updatePRDv8)**：
- Token 刷新竞态条件修复
- check1 去重（singletonKey + policy）
- 阶段 B 快速通道
- check2 发送前 hasStaffReplied 检查
- 超时配置调整（90s）

### 2.2 按功能模块组织

将内容按功能模块整合，而非按版本号堆叠：

```markdown
## 六、忙时回复系统

### 6.8 Settings 页面改造 + 意图识别增强 (v4.3)
[整合 v3 的内容]

### 6.9 固定回复功能 (v4.4)
[整合 v4 的内容]

### 6.10 意图识别精度优化 + 事件面板增强 (v4.5)
[整合 v5 的内容]

## 七、消息中台信息对齐 (v4.6)
[整合 v6 的内容]

### 6.11 系统查漏补缺 (v4.7)
[整合 v7 的内容]

### 6.12 稳定性修复 (v4.8)
[整合 v8 的内容]
```

### 2.3 更新版本演进表格

在 consolidated.md 的版本演进概览中添加新版本：

```markdown
| v4.3 | 2026-02-15 | Settings 页面改造 + 意图识别增强 | ✅ 已完成 |
| v4.4 | 2026-02-16 | 固定回复功能 | ✅ 已完成 |
| v4.5 | 2026-02-23 | 意图识别精度优化 + 事件面板增强 | ✅ 已完成 |
| v4.6 | 2026-02-23 | 客户名称 + 语音消息对齐 | ✅ 已完成 |
| v4.7 | 2026-02-26 | 系统查漏补缺（7个P0/P1修复 + 安全加固） | ✅ 已完成 |
| v4.8 | 2026-02-27 | 稳定性修复（Token竞态 + check1去重 + 快速通道） | ✅ 已完成 |
```

### 2.4 更新技术债务清单

标记已解决的技术债务：

```markdown
| ~~Prisma 使用 `db push` 而非 `migrate dev`~~ | ~~中~~ | ~~无 migration 历史记录~~ → v3.10 已修复 |
| ~~staffName 字符串匹配~~ | ~~低~~ | ~~白名单检查依赖字符串一致~~ → v4.7 已优化 |
| ~~hasStaffReplied 包含 senderType=2~~ | ~~低~~ | ~~AI 回复也被当作顾问已回复~~ → v4.7 已修复 |
| ~~Token 刷新竞态条件~~ | ~~中~~ | ~~40002 错误~~ → v4.8 已修复 |
| ~~check1 重复调度~~ | ~~低~~ | ~~浪费 API~~ → v4.8 已修复 |
```

## 阶段 3：同步主文档

### 3.1 更新 PRD.md

```markdown
# 消息中台 - 产品需求文档 (PRD)

> 项目：802 客服辅助系统 - 消息中台
> 版本：v4.8
> 日期：2026-02-27
> 状态：已部署

...

### 9.4 版本演进历史

| 版本 | 日期 | 主要功能 | 状态 |
|------|------|----------|------|
| v3.1~v3.10 | 2026-02-08~14 | ID 映射、API 文档、忙时回复核心 | ✅ 已完成 |
| v4.3 | 2026-02-15 | Settings 页面改造 + 意图识别增强 | ✅ 已完成 |
| v4.4 | 2026-02-16 | 固定回复功能 | ✅ 已完成 |
| v4.5 | 2026-02-23 | 意图识别精度优化 + 事件面板增强 | ✅ 已完成 |
| v4.6 | 2026-02-23 | 客户名称 + 语音消息对齐 | ✅ 已完成 |
| v4.7 | 2026-02-26 | 系统查漏补缺（7个P0/P1修复） | ✅ 已完成 |
| v4.8 | 2026-02-27 | 稳定性修复（Token竞态 + check1去重） | ✅ 已完成 |

详细的版本更新记录见 `specs/updatePRD-consolidated.md` (v4.8)
```

### 3.2 更新 AGENTS.md

```markdown
## 项目概述

802 客服辅助系统 - 消息中台，对接尘锋 SCRM + 企业微信。

- 后端：NestJS 10 + TypeScript + Prisma 5 + PG-Boss + Socket.io
- 前端：React 19 + Ant Design 5 + Zustand + Vite
- 数据库：PostgreSQL 16
- 进程管理：PM2（集群模式）
- 详细 PRD 见 `PRD.md` (v4.8)，功能更新汇总见 `specs/updatePRD-consolidated.md` (v4.8)

...

### PG-Boss singletonKey 去重（v4.8 新增）

`singletonKey` 在 `standard` policy（默认）下完全无效，必须改为 `short` 或 `stately`。

...

### Token 刷新竞态条件（v4.8 修复）

**问题**：多个并发请求同时发现 Token 过期，第一个开始刷新，其他直接 return 拿到旧 Token，导致 40002 错误。

**解决**：使用共享 Promise，所有并发请求等待同一个刷新任务完成。

...
```

## 阶段 4：清理旧文档

### 4.1 删除已整合的文档

```bash
# 删除 updatePRD 文件
git rm specs/updatePRDv3.md specs/updatePRDv4.md specs/updatePRDv5.md \
       specs/updatePRDv6.md specs/updatePRDv7.md specs/updatePRDv8.md

# 删除 PLAN 文件
git rm specs/updatePRDv3-PLAN.md specs/updatePRDv4-PLAN.md \
       specs/updatePRDv5-PLAN.md specs/updatePRDv6-PLAN.md \
       specs/updatePRDv7-PLAN.md specs/updatePRDv8-PLAN.md

# 删除查漏补缺文档（内容已整合到 v4.7）
git rm specs/忙时回复查漏补缺.md
```

### 4.2 提交变更

```bash
git commit -m "$(cat <<'EOF'
docs: 整合 v4.3~v4.8 功能更新到 consolidated 文档

## 主要变更

### 文档整合
- 整合 updatePRDv3~v8 到 updatePRD-consolidated.md (v3.10 → v4.8)
- 新增 242 行内容，涵盖 6 个版本的功能更新
- 新增章节：Settings 改造、固定回复、精度优化、信息对齐、查漏补缺、稳定性修复

### 版本号调整
- v3 → v4.3 (Settings 页面改造 + 意图识别增强)
- v4 → v4.4 (固定回复功能)
- v5 → v4.5 (意图识别精度优化 + 事件面板增强)
- v6 → v4.6 (客户名称 + 语音消息对齐)
- v7 → v4.7 (系统查漏补缺 7 个修复)
- v8 → v4.8 (稳定性修复：Token 竞态 + check1 去重 + 快速通道)

### PRD.md 更新
- 版本号：v3.1 → v4.8
- 更新版本演进历史表格
- 更新技术债务清单（标记 10 个已解决问题）
- 更新后续规划

### AGENTS.md 更新
- 新增 PG-Boss singletonKey 去重说明
- 新增 Token 刷新竞态条件修复
- 新增意图识别超时配置演进
- 新增固定回复功能说明
- 取消 .gitignore 忽略，纳入版本控制

### 文件清理
- 删除已整合的 updatePRDv3~v8.md (16 个文件)
- 删除忙时回复查漏补缺.md（内容已整合到 v4.7）
- 保留 Git 历史记录，可通过 git log 查看

Generated with Codex.
EOF
)"
```

### 4.3 推送到远程

```bash
git push origin main
```

## 结果验证

### 统计数据

- **变更文件**：20 个
- **新增行数**：+597 行
- **删除行数**：-4575 行
- **净减少**：-3978 行

### 文档状态

- ✅ `updatePRD-consolidated.md` 版本号：v4.8
- ✅ `PRD.md` 版本号：v4.8
- ✅ `AGENTS.md` 版本号：v4.8
- ✅ 所有 updatePRDv*.md 文件已删除
- ✅ Git 历史完整保留

### 质量检查

- [x] 版本演进时间线表格完整
- [x] 所有新功能都有对应章节
- [x] 技术债务清单已更新
- [x] Commit message 符合模板
- [x] 所有变更已推送到远程

## 经验总结

### 成功要素

1. **版本号规划清晰**：提前确定映射关系，避免冲突
2. **按功能模块组织**：而非按版本号堆叠，便于查阅
3. **保留 Git 历史**：使用 `git rm` 而非直接删除
4. **三文档同步**：确保 consolidated、PRD、AGENTS.md 版本号一致
5. **规范 Commit Message**：详细记录变更内容

### 注意事项

1. 整合时避免重复内容
2. 技术债务要标记已解决的项目
3. 版本表格要标记状态（✅/⏸️）
4. 新增章节要符合文档结构
5. 提交前要验证版本号一致性

---

*示例基于 802 客服系统实际整合过程*
*最后更新：2026-05-31*

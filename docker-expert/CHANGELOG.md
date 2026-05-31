# Docker Expert 技能更新日志

所有重要更新记录于此文件。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [2.1.0] - 2025-01-28

### 新增
- `scripts/docker-diagnose.sh` - Docker 一键诊断脚本
  - 环境检测（Docker 版本、守护进程状态）
  - 磁盘空间分析
  - 容器健康状态检查
  - 网络和镜像诊断
  - 支持指定容器详细诊断
- `scripts/docker-cleanup.sh` - Docker 安全清理脚本
  - 安全模式：只清理悬空资源
  - 激进模式：清理所有未使用资源
  - 交互式确认，防止误删

### 变更
- **SKILL.md 重构**
  - 统一使用祈使句写作风格（符合 skill-creator 规范）
  - 消除与 references 的重复内容，SKILL.md 只保留要点
  - 详细内容引用 references 文件
  - 版本号更新为 2.1.0

### 优化
- 减少 SKILL.md 体积（从 ~7.5KB 降至 ~5.5KB）
- 更清晰的文档结构，符合 Progressive Disclosure 原则

## [2.0.0] - 2025-01-28

### 新增
- 融合 5 个优秀 Docker 技能的精华：
  - docker-expert (sickn33/antigravity-awesome-skills)
  - docker-containerization (aj-geddes/useful-ai-prompts)
  - docker (bobmatnyc/claude-mpm-skills)
  - docker-composer (eddiebe147/claude-settings)
  - docker-best-practices (josiahsiegel/claude-plugin-marketplace)

- 完整的 references 文档：
  - `dockerfile-patterns.md` - 2025 基础镜像推荐、多阶段构建模板
  - `compose-orchestration.md` - 健康检查、网络隔离、Monorepo 模式
  - `security-hardening.md` - 非 root 用户、BuildKit Secrets、能力限制
  - `cicd-integration.md` - GitHub Actions、GitLab CI 完整流水线
  - `troubleshooting.md` - 故障诊断、平台特定指南

### 特性
- 2025 新镜像支持（Wolfi/Chainguard）
- BuildKit 缓存挂载模式
- 范围检测（自动识别超出 Docker 范围的问题）
- 代码审查清单
- 快速命令参考

## [1.0.0] - 2025-01-28

### 初始版本
- 基于 docker-expert 技能的简化版本
- 基础 Dockerfile 优化指南
- Docker Compose 编排模式

---

## 来源致谢

本技能整合了以下优秀技能的精华：

| 来源 | 贡献 |
|------|------|
| docker-expert | 范围检测、基础架构 |
| docker (bobmatnyc) | Progressive Disclosure 设计 |
| docker-best-practices | 2025 新镜像推荐 |
| docker-composer | Monorepo 模式 |
| docker-containerization | CI/CD 集成 |

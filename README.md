# NoKuGua Skills

我自己常用的一组 Codex / Agents skills，按「一个技能一个目录」整理，方便单独安装、维护和开源分享。

## Skills

| Skill | 用途 |
| --- | --- |
| `docker-expert` | Docker 容器化专家技能，覆盖 Dockerfile 优化、多阶段构建、Compose 编排、安全加固、CI/CD 集成和故障排查。 |
| `spec-flow` | Specs 编程工作流，按照 PRD -> PLAN -> 增量开发的方式推进需求、任务拆解和实现验收。 |
| `specs-consolidator` | PRD/updatePRD 文档整合工具，用于合并版本文档、更新 consolidated 文档，并同步 PRD/AGENTS 信息。 |

## Repository Layout

```text
.
├── docker-expert/
│   ├── SKILL.md
│   ├── CHANGELOG.md
│   ├── references/
│   └── scripts/
├── spec-flow/
│   ├── SKILL.md
│   └── references/
└── specs-consolidator/
    ├── SKILL.md
    ├── examples/
    ├── references/
    └── scripts/
```

## Install

复制需要的技能目录到本机 skills 目录即可：

```powershell
Copy-Item -Recurse .\docker-expert "$env:USERPROFILE\.agents\skills\docker-expert"
Copy-Item -Recurse .\spec-flow "$env:USERPROFILE\.agents\skills\spec-flow"
Copy-Item -Recurse .\specs-consolidator "$env:USERPROFILE\.agents\skills\specs-consolidator"
```

也可以只安装其中一个技能，例如：

```powershell
Copy-Item -Recurse .\spec-flow "$env:USERPROFILE\.agents\skills\spec-flow"
```

## Safety Notes

- `docker-expert/scripts/` 里包含 Docker 诊断和清理脚本。清理脚本会调用 Docker prune 类命令，运行前请先阅读脚本输出，并确认当前机器上的容器、镜像、网络和缓存可以被清理。
- 文档中的 token、password、secret、路径等内容均为示例写法，用于说明 Docker/CI 配置模式，不应直接用于生产环境。

## License

MIT
